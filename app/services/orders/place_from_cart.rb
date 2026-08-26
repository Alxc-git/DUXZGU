module Orders
  # Turns the session cart into orders. Each cart line keeps its own row, because
  # fulfillment, tracking and refunds all run per variant — that is how the
  # supplier ships them — and a shared reference in metadata ties the rows back
  # to the single checkout the customer went through.
  #
  # Payment is deliberately not part of this: orders are left `pending` and the
  # payment handoff happens after this service returns.
  class PlaceFromCart < ApplicationService
    def initialize(store:, cart:, details:)
      @store = store
      @cart = cart
      @details = details
    end

    def call
      reference = self.class.build_reference
      estimate = delivery_estimate

      ActiveRecord::Base.transaction do
        customer = upsert_customer

        cart.lines.each_with_index.map do |line, index|
          create_order(line, reference:, customer:, estimate:, first: index.zero?)
        end
      end
    end

    def self.build_reference
      "LX-#{SecureRandom.alphanumeric(8).upcase}"
    end

    private

    attr_reader :store, :cart, :details

    def create_order(line, reference:, customer:, estimate:, first:)
      order = store.orders.new(
        product: line.product,
        variant: line.variant,
        quantity: line.quantity,
        currency: line.product.currency,
        # Shipping is charged once per checkout, on the first line.
        shipping_cents: first ? store.shipping_cents : 0,
        discount_cents: cart.discount_for(line),
        customer:,
        # Frozen at checkout: the customer is always shown the promise that was
        # made to them, not whatever the carrier quotes weeks later.
        delivery_min_days: estimate&.min_days,
        delivery_max_days: estimate&.max_days,
        shipping_carrier: estimate&.carrier,
        # Frozen with the order: the emails must speak the language the customer
        # was reading, not whatever the next request happens to set.
        locale: I18n.locale.to_s,
        metadata: { "checkout_reference" => reference }
      )
      order.assign_attributes(details.attributes_for_order)
      order.recalculate_totals!
      order.save!
      order
    end

    # One quote per checkout rather than one per line: the parcel ships together.
    def delivery_estimate
      first = cart.lines.first
      return if first.blank? || details.country.blank?

      Suppliers::Cj::DeliveryEstimate.call(
        client: Suppliers.for(store),
        country: details.country,
        postal_code: details.postal_code,
        variant_ids: cart.lines.filter_map { |line| line.variant.supplier_variant_id },
        quantity: cart.count
      )
    rescue Suppliers::UnsupportedSupplier, StandardError => e
      Rails.logger.warn("[Commande] estimation ignoree: #{e.class} #{e.message[0, 90]}")
      nil
    end

    def upsert_customer
      customer = store.customers.find_or_initialize_by(email: details.email.to_s.strip.downcase)
      customer.first_name = details.first_name
      customer.last_name = details.last_name
      customer.phone = details.phone.presence || customer.phone
      customer.save!
      customer
    end
  end
end
