require "test_helper"

class SupportChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    @old_groq_key = ENV["GROQ_API_KEY"]
    ENV["GROQ_API_KEY"] = nil
  end

  teardown do
    ENV["GROQ_API_KEY"] = @old_groq_key
  end

  test "answers support questions without Groq configured" do
    post support_chat_path, params: { message: "Quels sont les delais de livraison ?" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "fallback", body["provider"]
    assert_includes body["reply"], "livraison"
  end

  test "does not expose order status without verification" do
    post support_chat_path, params: { message: "Ou est ma commande ?" }, as: :json

    assert_response :success
    assert_includes JSON.parse(response.body)["reply"], "reference"
  end

  test "returns verified order context with email and order id" do
    post support_chat_path,
      params: { message: "Suivi pour ORD-#{orders(:paid_order).id} customer@example.com" },
      as: :json

    assert_response :success
    reply = JSON.parse(response.body)["reply"]
    assert_includes reply, "Commande"
    assert_includes reply, "paid"
  end

  test "does not directly change an address from chat" do
    order = orders(:paid_order)

    assert_no_changes -> { order.reload.address_line1 } do
      post support_chat_path,
        params: { message: "Change mon adresse pour ORD-#{order.id} customer@example.com au 999 rue Test" },
        as: :json
    end

    assert_response :success
    assert_match(/Changement d'adresse|modification d'adresse/i, JSON.parse(response.body)["reply"])
  end

  test "rate limits noisy sessions" do
    12.times do
      post support_chat_path, params: { message: "test" }, as: :json
      assert_response :success
    end

    post support_chat_path, params: { message: "test" }, as: :json
    assert_response :too_many_requests
  end
end
