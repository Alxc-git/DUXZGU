class OrderMailer < ApplicationMailer
  # Sent the moment payment succeeds. Without it a customer has no trace of the
  # purchase once they close the tab, which is the first cause of "where is my
  # order" messages and of payments disputed with the bank.
  def confirmation(order_ids)
    return unless load(order_ids)

    I18n.with_locale(@locale) do
      mail(**headers(t("mailer.confirmation_subject", reference: @first.reference)))
    end
  end

  # Sent once CJ hands the parcel to a carrier and a tracking number lands.
  def shipped(order_ids)
    return unless load(order_ids)

    I18n.with_locale(@locale) do
      mail(**headers(t("mailer.shipped_subject")))
    end
  end

  private

  def load(order_ids)
    @orders = Order.where(id: Array(order_ids)).includes(:store, :product, :variant).to_a
    @first = @orders.first
    return false if @first.blank?

    @store = @first.store
    @total_cents = @orders.sum(&:total_cents)
    @locale = @first.locale.presence || I18n.default_locale
    true
  end

  # Replies land in the shop's inbox rather than in a no-reply void.
  def headers(subject)
    support = @store.support_email.presence

    {
      to: @first.email,
      subject: "#{subject} | #{@store.name}",
      from: support || self.class.default[:from],
      reply_to: support
    }.compact
  end
end
