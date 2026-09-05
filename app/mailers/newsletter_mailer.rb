class NewsletterMailer < ApplicationMailer
  # The welcome discount, sent the moment an address is left in the footer form.
  #
  # Takes the id rather than the record because `deliver_later` serialises its
  # arguments through Active Job, and reads the code at delivery time so a shop
  # that edits the campaign between enqueue and send mails the edited one.
  def welcome(subscriber_id)
    @subscriber = NewsletterSubscriber.find_by(id: subscriber_id)
    return if @subscriber.blank?

    @store = @subscriber.store
    @discount = NewsletterSubscriber.welcome_discount(@store)
    # A shop switches the campaign off by deactivating the code or letting it
    # expire. Mailing it anyway would hand out something that is refused at
    # checkout, which reads as a broken shop rather than a closed offer.
    return if @discount.blank? || !@discount.active? || @discount.expired?

    I18n.with_locale(@subscriber.locale.presence || I18n.default_locale) do
      @amount = discount_amount
      mail(**headers)
    end
  end

  private

  # "10 %" or "5,00 $": the campaign is a percentage by default, but the code it
  # points at can be a fixed amount, and the email has to name either one.
  def discount_amount
    return t("mailer.newsletter_percent", percent: @discount.percent_off) if @discount.percentage?

    MoneyFormatter.format(@discount.amount_off_cents, @store.currency)
  end

  # Replies land in the shop's inbox rather than in a no-reply void.
  def headers
    support = @store.support_email.presence

    {
      to: @subscriber.email,
      subject: "#{t("mailer.newsletter_subject", amount: @amount)} | #{@store.name}",
      from: support || self.class.default[:from],
      reply_to: support
    }.compact
  end
end
