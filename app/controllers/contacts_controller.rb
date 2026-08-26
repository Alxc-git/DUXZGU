class ContactsController < ApplicationController
  before_action :require_current_store!

  def new
    @message = ContactMessage.new(prefill)
  end

  def create
    @message = ContactMessage.new(message_params)

    return render :new, status: :unprocessable_entity unless @message.valid?

    deliver(@message)
    redirect_to contact_path, notice: t("contact.sent")
  end

  private

  def message_params
    params.require(:contact_message).permit(:name, :email, :subject, :body, :order_reference)
  end

  # The last order of this session, so a customer writing about it does not have
  # to dig the reference out of their inbox.
  def prefill
    order = Current.store.orders.where(id: session[:placed_order_ids]).order(:created_at).last
    return {} if order.blank?

    {
      name: order.customer_name.presence,
      email: order.email,
      order_reference: order.metadata["checkout_reference"]
    }.compact
  end

  # A mail server that is not reachable must never cost the customer their
  # message: the failure is logged and the page still confirms.
  def deliver(message)
    return Rails.logger.warn("[Contact] no support email configured") if Current.store.support_email.blank?

    ContactMailer.enquiry(Current.store, message.attributes).deliver_later
  rescue StandardError => e
    Rails.logger.error("[Contact] could not send: #{e.class} #{e.message}")
  end
end
