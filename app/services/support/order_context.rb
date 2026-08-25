module Support
  class OrderContext
    Result = Data.define(:orders, :verification_hint)

    REFERENCE_PATTERN = /\b(?:LX-[A-Z0-9]{8}|ORD-\d+)\b/i
    EMAIL_PATTERN = /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i

    def self.call(...)
      new(...).call
    end

    def initialize(store:, message:, session_order_ids:)
      @store = store
      @message = message.to_s
      @session_order_ids = Array(session_order_ids).compact
    end

    def call
      orders = session_orders.presence || verified_orders
      Result.new(orders: orders.map { |order| summary(order) }, verification_hint: verification_hint(orders))
    end

    private

    attr_reader :store, :message, :session_order_ids

    def session_orders
      return [] if session_order_ids.blank?

      store.orders.includes(:product, :variant).where(id: session_order_ids).recent.limit(3).to_a
    end

    def verified_orders
      return [] if email.blank? || reference.blank?

      scope = store.orders.includes(:product, :variant).where("lower(email) = ?", email.downcase)
      if reference.start_with?("ORD-")
        scope.where(id: reference.delete_prefix("ORD-").to_i).to_a
      else
        scope.where("metadata ->> 'checkout_reference' = ?", reference).to_a
      end
    end

    def email
      @email ||= message[EMAIL_PATTERN].to_s
    end

    def reference
      @reference ||= message[REFERENCE_PATTERN].to_s.upcase
    end

    def summary(order)
      {
        reference: order.metadata["checkout_reference"].presence || "ORD-#{order.id}",
        status: order.status,
        product: order.line_item_name,
        quantity: order.quantity,
        total: order.formatted_total,
        paid_at: order.paid_at&.strftime("%Y-%m-%d"),
        supplier_status: order.supplier_status,
        tracking_number: order.tracking_number,
        tracking_url: order.tracking_url,
        estimated_delivery: estimated_delivery(order),
        address_change_allowed: address_change_allowed?(order),
        address_change_reason: address_change_reason(order)
      }.compact_blank
    end

    def estimated_delivery(order)
      base = order.paid_at || order.created_at || Time.current
      start_date = business_days_after(base.to_date, 7)
      end_date = business_days_after(base.to_date, 14)

      "#{format_date(start_date)} - #{format_date(end_date)}"
    end

    def business_days_after(date, count)
      count.times do
        date = date.next_day
        date = date.next_day while date.saturday? || date.sunday?
      end
      date
    end

    def format_date(date)
      I18n.l(date, format: "%-d %b")
    rescue I18n::MissingTranslationData
      date.strftime("%Y-%m-%d")
    end

    def address_change_allowed?(order)
      order.status.in?(%w[pending checkout_created paid]) && order.supplier_order_id.blank?
    end

    def address_change_reason(order)
      return "commande pas encore envoyee au fournisseur" if address_change_allowed?(order)
      return "commande deja envoyee a CJ" if order.supplier_order_id.present?

      "statut actuel: #{order.status}"
    end

    def verification_hint(orders)
      return "verified" if orders.any?
      return "missing_email_or_reference" if message.match?(REFERENCE_PATTERN) || message.match?(EMAIL_PATTERN)

      "ask_for_email_and_reference"
    end
  end
end
