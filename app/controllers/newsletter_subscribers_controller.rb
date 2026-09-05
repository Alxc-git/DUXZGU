class NewsletterSubscribersController < ApplicationController
  before_action :require_current_store!
  before_action :rate_limit!

  # Public, unauthenticated, and it causes mail to leave the server, so it is
  # capped per session the way the assistant and the address lookup are.
  SIGNUPS_PER_WINDOW = 5
  WINDOW = 10.minutes

  def create
    subscriber = Current.store.newsletter_subscribers.find_or_initialize_by(email: submitted_email) do |record|
      record.locale = I18n.locale
      record.consented_at = Time.current
    end

    unless persist(subscriber)
      return redirect_back fallback_location: root_path, alert: subscriber.errors[:email].first
    end

    deliver_welcome(subscriber) unless subscriber.welcomed?
    redirect_back fallback_location: root_path, notice: t("store.newsletter.thanks")
  end

  private

  def submitted_email
    NewsletterSubscriber.normalize_value_for(:email, params[:email])
  end

  # An address that comes back is not an error. An earlier unsubscribe is undone
  # and consent re-recorded; an address already on the list is left untouched and
  # still answered with the same confirmation, so the form cannot be used to test
  # who is on it.
  def persist(subscriber)
    return subscriber.save if subscriber.new_record?
    return true if subscriber.subscribed?

    subscriber.update(unsubscribed_at: nil, consented_at: Time.current)
  end

  # A mail server that is not reachable must never cost the shop the address:
  # the row is already saved, the failure is logged, and welcome_sent_at stays
  # unset so the code can still go out on a later attempt.
  def deliver_welcome(subscriber)
    NewsletterMailer.welcome(subscriber.id).deliver_later
    subscriber.update!(welcome_sent_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("[Newsletter] could not send the welcome code: #{e.class} #{e.message}")
  end

  def rate_limit!
    cutoff = WINDOW.ago.to_i
    recent = Array(session[:newsletter_signups]).select { |timestamp| timestamp.to_i > cutoff }
    return session[:newsletter_signups] = recent.push(Time.current.to_i) if recent.size < SIGNUPS_PER_WINDOW

    redirect_back fallback_location: root_path, alert: t("store.newsletter.too_many")
  end
end
