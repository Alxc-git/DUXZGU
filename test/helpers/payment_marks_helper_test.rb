require "test_helper"

class PaymentMarksHelperTest < ActionView::TestCase
  include PaymentMarksHelper

  test "the default row renders every accepted mark" do
    html = payment_marks

    assert_equal PaymentMarksHelper::PAYMENT_MARKS.length, html.scan("payment-mark ").length
    assert_includes html, 'aria-label="Visa"'
    assert_includes html, 'aria-label="PayPal"'
  end

  test "a caller can pick which marks to show" do
    html = payment_marks(%w[visa stripe])

    assert_includes html, 'aria-label="Visa"'
    assert_includes html, 'aria-label="Stripe"'
    assert_not_includes html, 'aria-label="PayPal"'
  end

  test "extra classes are merged rather than replacing the base class" do
    assert_includes payment_marks(class: "payment-marks--sm"), 'class="payment-marks payment-marks--sm"'
  end

  test "an unknown mark renders nothing instead of raising" do
    assert_equal "", payment_mark("bitcoin")
  end
end
