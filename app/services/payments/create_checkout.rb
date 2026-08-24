module Payments
  class CreateCheckout < ApplicationService
    Error = Class.new(StandardError)
    Result = Data.define(:order, :session) do
      def url
        session.url
      end
    end

    def initialize(store:, product:, quantity:, request:, variant_id: nil)
      @store = store
      @product = product
      @quantity = quantity.to_i
      @request = request
      @variant_id = variant_id
    end

    def call
      raise Error, "Stripe n'est pas encore configure. Ajoutez STRIPE_SECRET_KEY puis relancez le serveur." if Stripe.api_key.blank?
      raise Error, "Produit indisponible" unless product.store_id == store.id && product.active?
      raise Error, "Veuillez choisir une couleur" if product.variants? && variant.blank?

      order = build_order
      session = create_stripe_session(order)
      raise Error, "Stripe n'a pas retourne d'URL de paiement" if session.url.blank?

      order.update!(
        status: :checkout_created,
        stripe_checkout_session_id: session.id,
        metadata: order.metadata.merge("stripe_checkout_url" => session.url)
      )

      Result.new(order:, session:)
    end

    private

    attr_reader :store, :product, :quantity, :request, :variant_id

    def variant
      return @variant if defined?(@variant)

      @variant = product.variant_for(variant_id)
    end

    def build_order
      order = store.orders.new(
        product:,
        variant:,
        quantity: [ quantity, 1 ].max,
        currency: product.currency,
        shipping_cents: store.shipping_cents
      )
      order.recalculate_totals!
      order.save!
      order
    end

    def create_stripe_session(order)
      params = {
        mode: "payment",
        locale: store.checkout_locale,
        client_reference_id: order.id.to_s,
        customer_creation: "always",
        success_url: "#{checkout_url(:checkout_success_url)}?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: checkout_url(:checkout_cancel_url),
        # Without this the webhook has no address and the supplier order cannot ship.
        shipping_address_collection: { allowed_countries: store.shipping_countries },
        billing_address_collection: "auto",
        phone_number_collection: { enabled: true },
        line_items: [ line_item(order) ],
        metadata: reference_metadata(order),
        payment_intent_data: { metadata: reference_metadata(order) }
      }
      params[:shipping_options] = [ shipping_option(order) ] unless store.free_shipping?

      Stripe::Checkout::Session.create(params, stripe_options)
    end

    def line_item(order)
      {
        quantity: order.quantity,
        price_data: {
          currency: order.currency,
          unit_amount: order.unit_price_cents,
          product_data: {
            name: order.line_item_name,
            images: line_item_images,
            metadata: reference_metadata(order)
          }.compact_blank
        }
      }
    end

    # Stripe fetches these server-side, so only publicly reachable URLs are worth sending.
    def line_item_images
      return [] unless request.protocol == "https://"

      image = variant&.display_image || product.images.first
      return [] if image.blank?

      [ Rails.application.routes.url_helpers.rails_blob_url(image, host: request.host_with_port, protocol: request.protocol) ]
    rescue StandardError => e
      Rails.logger.warn("[Checkout] could not build image URL: #{e.message}")
      []
    end

    def shipping_option(order)
      {
        shipping_rate_data: {
          type: "fixed_amount",
          display_name: store.settings["shipping_label"].presence || "Livraison",
          fixed_amount: { amount: order.shipping_cents, currency: order.currency }
        }
      }
    end

    def reference_metadata(order)
      {
        store_id: store.id,
        product_id: product.id,
        variant_id: variant&.id,
        order_id: order.id
      }.compact
    end

    def checkout_url(helper)
      Rails.application.routes.url_helpers.public_send(
        helper,
        host: request.host_with_port,
        protocol: request.protocol
      )
    end

    def stripe_options
      store.stripe_account_id.present? ? { stripe_account: store.stripe_account_id } : {}
    end
  end
end
