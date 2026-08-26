class OrderMailer < ApplicationMailer
  # Sent the moment payment succeeds. Without it a customer has no trace of the
  # purchase once they close the tab, which is the first cause of "where is my
  # order" messages and of payments disputed with the bank.
  def confirmation(order_ids)
    return unless load(order_ids)

    mail(**headers("Commande #{@first.reference} confirmee"))
  end

  # Sent once CJ hands the parcel to a carrier and a tracking number lands.
  def shipped(order_ids)
    return unless load(order_ids)

    mail(**headers("Votre montre est en route"))
  end

  private

  def load(order_ids)
    @orders = Order.where(id: Array(order_ids)).includes(:store, :product, :variant).to_a
    @first = @orders.first
    return false if @first.blank?

    @store = @first.store
    @total_cents = @orders.sum(&:total_cents)
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
