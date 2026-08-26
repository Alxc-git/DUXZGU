require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  setup do
    @store = stores(:demo)
    @store.update!(settings: @store.settings.merge("support_email" => "aide@exemple.ca"))
    @attributes = ContactMessage.new(
      name: "Ada Lovelace",
      email: "client@exemple.ca",
      subject: "commande",
      body: "Ou en est ma montre ?"
    ).attributes
  end

  # The controller sends this one with `deliver_later`, so nothing renders the
  # mail during the request: a template or attribute error surfaces only in the
  # worker, silently, and the shop never learns a customer wrote in. Rendering it
  # here is what keeps that failure visible.
  test "the enquiry renders and reaches the shop with the customer as reply-to" do
    mail = ContactMailer.enquiry(@store, @attributes)

    assert_equal [ "aide@exemple.ca" ], mail.to
    assert_equal [ "aide@exemple.ca" ], mail.from
    assert_equal [ "client@exemple.ca" ], mail.reply_to
    assert_match "Ada Lovelace", mail.subject
    assert_match @store.name, mail.subject
    assert_match "Ou en est ma montre ?", mail.text_part.body.to_s
  end

  test "a message without a chosen subject still gets one" do
    mail = ContactMailer.enquiry(@store, @attributes.merge("subject" => nil))

    assert mail.subject.present?
    assert_match "Ada Lovelace", mail.subject
  end
end
