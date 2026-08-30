require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    stores(:demo).update!(settings: stores(:demo).settings.merge("support_email" => "aide@exemple.ca"))
  end

  test "renders the contact form" do
    get contact_path

    assert_response :success
    assert_select "form[action=?]", contact_path
    assert_select "#contact_message_body"
    assert_select ".contact-select select#contact_message_subject", 1
    assert_select ".contact-select__chevron svg", 1
    assert_select ".field__hint", 0
  end


  # The page used to stop dead after the form while every other page carries the
  # FAQ and the closing call to action below its content. Half of what people
  # write in about is answered in that FAQ, so it earns its place here most.
  test "the page carries the same closing sections as the rest of the site" do
    get contact_path

    assert_response :success
    assert_select "section.faq"
    assert_select "section.footer-cta"
  end

  # The lead and the FAQ intro were both written straight into the templates, so
  # an English visitor read them in French. They live in the locale files now.
  test "an english visitor reads the page in english" do
    get contact_path(locale: "en")

    assert_response :success
    assert_select ".contact__lead", text: I18n.t("contact.lead", locale: :en)
    assert_select ".faq__lead", text: I18n.t("sections.faq_lead", locale: :en)
    assert_no_match "It is on your confirmation email.", response.body
    assert_no_match "translation missing", response.body
  end
  test "refuses a message with no body" do
    assert_no_enqueued_emails do
      post contact_path, params: { contact_message: { name: "Alexis", email: "alexis@exemple.ca", body: "" } }
    end

    assert_response :unprocessable_entity
    assert_select ".checkout__errors", text: /message/i
  end

  test "refuses a malformed email" do
    assert_no_enqueued_emails do
      post contact_path, params: { contact_message: { name: "Alexis", email: "nope", body: "Bonjour" } }
    end

    assert_response :unprocessable_entity
    assert_select ".checkout__errors", text: /courriel/i
  end

  test "refuses a subject that is not offered" do
    post contact_path, params: {
      contact_message: { name: "Alexis", email: "alexis@exemple.ca", body: "Bonjour", subject: "<script>" }
    }

    assert_response :unprocessable_entity
  end

  test "sends a valid message to the store support address" do
    assert_enqueued_emails 1 do
      post contact_path, params: {
        contact_message: {
          name: "Alexis Giard",
          email: "alexis@exemple.ca",
          subject: "Livraison et suivi",
          order_reference: "LX-ABCD1234",
          body: "Ou en est ma commande ?"
        }
      }
    end

    assert_redirected_to contact_path
    assert_match "Message envoye", flash[:notice]
  end

  test "a store with no support address still accepts the message" do
    stores(:demo).update!(settings: stores(:demo).settings.except("support_email"))

    assert_no_enqueued_emails do
      post contact_path, params: {
        contact_message: { name: "Alexis", email: "alexis@exemple.ca", body: "Bonjour" }
      }
    end

    assert_redirected_to contact_path
  end

  test "prefills from the order placed in this session" do
    post cart_lines_path, params: {
      product_id: products(:demo_product).id, variant_id: variants(:black).id, quantity: 1
    }
    post checkout_path, params: {
      checkout_form: {
        email: "client@exemple.ca", first_name: "Ada", last_name: "Lovelace",
        phone: "+1 514 555 0123",
        address_line1: "1 rue Test", city: "Montreal", postal_code: "H2X 1Y6", country: "CA"
      }
    }
    post payment_path

    get contact_path

    assert_response :success
    assert_select "#contact_message_email[value=?]", "client@exemple.ca"
    assert_select "#contact_message_name[value=?]", "Ada Lovelace"
  end
end
