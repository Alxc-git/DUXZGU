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

      ActiveRecord::Base.transaction do
        customer = upsert_customer

        cart.lines.each_with_index.map do |line, index|
          create_order(line, reference:, customer:, first: index.zero?)
        end
      end
    end

    def self.build_reference
      "LX-#{SecureRandom.alphanumeric(8).upcase}"
    end

    private

    attr_reader :store, :cart, :details

    def create_order(line, reference:, customer:, first:)
      order = store.orders.new(
        product: line.product,
        variant: line.variant,
        quantity: line.quantity,
        currency: line.product.currency,
        # Shipping is charged once per checkout, on the first line.
        shipping_cents: first ? store.shipping_cents : 0,
        customer:,
        metadata: { "checkout_reference" => reference }
      )
      order.assign_attributes(details.attributes_for_order)
      order.recalculate_totals!
      order.save!
      order
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
