require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  setup do
    @store = stores(:demo)
    @store.update!(settings: @store.settings.merge("support_email" => "aide@exemple.ca"))
    @order = orders(:paid_order)
    @order.update!(
      email: "client@exemple.ca", first_name: "Ada", last_name: "Lovelace",
      paid_at: Time.current, delivery_min_days: 6, delivery_max_days: 9,
      shipping_carrier: "CJPacket Sensitive",
      metadata: { "checkout_reference" => "LX-ABCD1234" }
    )
  end

  test "the confirmation carries the reference, the total and the quoted window" do
    mail = OrderMailer.confirmation([ @order.id ])

    assert_equal [ "client@exemple.ca" ], mail.to
    assert_match "LX-ABCD1234", mail.subject
    body = mail.text_part.body.to_s
    assert_match "LX-ABCD1234", body
    assert_match @order.formatted_total, body
    assert_match "CJPacket Sensitive", body
    assert_match (Date.current + 6).to_s, body
    assert_match (Date.current + 9).to_s, body
  end

  test "replies reach the shop rather than a no-reply address" do
    mail = OrderMailer.confirmation([ @order.id ])

    assert_equal [ "aide@exemple.ca" ], mail.reply_to
    assert_equal [ "aide@exemple.ca" ], mail.from
  end

  test "the shipped notice carries the tracking number and its link" do
    @order.update!(tracking_number: "CJ123456789CA", tracking_url: "https://t.17track.net/en#nums=CJ123456789CA")

    mail = OrderMailer.shipped([ @order.id ])
    body = mail.text_part.body.to_s

    assert_match "CJ123456789CA", body
    assert_match "17track.net", body
  end

  test "an order with no email produces no mail at all" do
    @order.update!(email: nil)

    assert_nil OrderMailer.confirmation([ @order.id ]).message.to
  end

  # Falling back matters: CJ is not always reachable when the order is placed.
  test "an order quoted no window still states a delivery estimate" do
    @order.update!(delivery_min_days: nil, delivery_max_days: nil)

    body = OrderMailer.confirmation([ @order.id ]).text_part.body.to_s

    assert_match (Date.current + Order::DEFAULT_DELIVERY_DAYS.first).to_s, body
  end
end
