class ContactMailer < ApplicationMailer
  # Forwards a contact-page message to the store's support address, with the
  # customer set as reply-to so answering is a single click.
  #
  # Takes the attributes rather than the ContactMessage itself: `deliver_later`
  # serialises its arguments through Active Job, which only accepts primitives
  # and Global IDs, never a plain Active Model object.
  def enquiry(store, attributes)
    @store = store
    @message = ContactMessage.new(attributes)

    mail(
      to: store.support_email,
      from: store.support_email,
      reply_to: @message.email,
      subject: "[#{store.name}] #{@message.subject_or_default} - #{@message.name}"
    )
  end
end
