module PaymentMarksHelper
  # Card and wallet marks drawn inline, so the trust row costs no extra request and
  # stays crisp on every screen. Each mark is drawn in a 40x26 box (card ratio) and
  # sized from CSS, so the caller only picks which ones to show.
  PAYMENT_MARKS = %w[visa mastercard amex paypal apple-pay google-pay].freeze

  PAYMENT_LABELS = {
    "visa" => "Visa",
    "mastercard" => "Mastercard",
    "amex" => "American Express",
    "paypal" => "PayPal",
    "apple-pay" => "Apple Pay",
    "google-pay" => "Google Pay",
    "stripe" => "Stripe"
  }.freeze

  MARK_FONT = "Inter, 'Helvetica Neue', Arial, sans-serif".freeze

  # The Apple silhouette, drawn in a 24x24 box and scaled into place.
  APPLE_GLYPH = "M17.05 12.9c-.03-2.5 2.04-3.7 2.13-3.76-1.16-1.7-2.97-1.93-3.61-1.96-1.54-.16-3 .9-3.78.9" \
                "-.78 0-1.98-.88-3.25-.86-1.67.03-3.21.97-4.07 2.46-1.73 3-.44 7.45 1.25 9.89.83 1.19 1.81 " \
                "2.53 3.11 2.48 1.25-.05 1.72-.81 3.23-.81 1.5 0 1.93.81 3.25.78 1.34-.02 2.19-1.21 3.01-2.41" \
                ".95-1.38 1.34-2.72 1.36-2.79-.03-.01-2.6-1-2.63-3.92z" \
                "M14.9 5.6c.69-.83 1.15-1.99 1.02-3.14-.99.04-2.19.66-2.9 1.49-.64.73-1.19 1.91-1.04 3.04 " \
                "1.1.09 2.23-.56 2.92-1.39z".freeze

  # A row of payment marks, e.g. under the add-to-cart button or in the footer.
  def payment_marks(marks = PAYMENT_MARKS, label: "Moyens de paiement acceptes", **options)
    options[:class] = [ "payment-marks", options[:class] ].compact.join(" ")

    tag.ul(role: "list", "aria-label": label, **options) do
      safe_join(Array(marks).map { |mark| tag.li(payment_mark(mark), class: "payment-marks__item") })
    end
  end

  def payment_mark(name)
    body = case name.to_s
    when "visa" then visa_mark
    when "mastercard" then mastercard_mark
    when "amex" then amex_mark
    when "paypal" then paypal_mark
    when "apple-pay" then apple_pay_mark
    when "google-pay" then google_pay_mark
    when "stripe" then stripe_mark
    end
    return "" if body.blank?

    tag.svg(
      body,
      class: "payment-mark payment-mark--#{name}",
      viewBox: "0 0 40 26",
      role: "img",
      "aria-label": PAYMENT_LABELS[name.to_s] || name.to_s.humanize
    )
  end

  private

  # `length` pins the run to an exact width and lets the browser stretch the
  # glyphs to reach it. Without it every mark is drawn at whatever width the
  # available font happens to produce, so the plates look different before and
  # after the web font arrives — and the widest of them, AMEX, ran edge to edge.
  def mark_text(content, x:, length:, y: 17.4, size: 10.5, weight: 700, fill: "#111111", **options)
    tag.text(
      content,
      x: x,
      y: y,
      fill: fill,
      "font-family": MARK_FONT,
      "font-size": size,
      "font-weight": weight,
      textLength: length,
      lengthAdjust: "spacingAndGlyphs",
      **options
    )
  end

  def mark_plate(fill: "#ffffff")
    tag.rect(width: 40, height: 26, rx: 4, fill: fill)
  end

  def visa_mark
    safe_join([
      mark_plate,
      mark_text("VISA", x: 20, y: 17.6, size: 11, length: 26, fill: "#1434CB",
                "text-anchor": "middle", "font-style": "italic")
    ])
  end

  def mastercard_mark
    safe_join([
      mark_plate,
      tag.circle(cx: 16, cy: 13, r: 7.2, fill: "#EB001B"),
      tag.circle(cx: 24, cy: 13, r: 7.2, fill: "#F79E1B"),
      # The lens where both discs overlap, the mark's signature detail.
      tag.path(d: "M20 7.013a7.2 7.2 0 010 11.974 7.2 7.2 0 010-11.974", fill: "#FF5F00")
    ])
  end

  def amex_mark
    safe_join([
      mark_plate(fill: "#006FCF"),
      mark_text("AMEX", x: 20, y: 16.9, size: 8.4, length: 25, fill: "#ffffff",
                "text-anchor": "middle")
    ])
  end

  def paypal_mark
    safe_join([
      mark_plate,
      mark_text("Pay", x: 6.5, y: 17.2, size: 9.6, length: 14, fill: "#003087"),
      mark_text("Pal", x: 20.5, y: 17.2, size: 9.6, length: 13, fill: "#009CDE")
    ])
  end

  def apple_pay_mark
    safe_join([
      mark_plate,
      tag.g(tag.path(d: APPLE_GLYPH, fill: "#111111"), transform: "translate(4.2 3.4) scale(0.6)"),
      mark_text("Pay", x: 19.6, y: 17.2, size: 9.6, length: 15.5, fill: "#111111")
    ])
  end

  def google_pay_mark
    safe_join([
      mark_plate,
      mark_text("G", x: 7, y: 17.4, size: 11, length: 8, fill: "#4285F4"),
      mark_text("Pay", x: 16.5, y: 17.4, size: 9.6, length: 16, fill: "#5F6368")
    ])
  end

  def stripe_mark
    safe_join([
      mark_plate(fill: "#635BFF"),
      mark_text("stripe", x: 20, y: 17, size: 8.8, length: 25, fill: "#ffffff",
                "text-anchor": "middle")
    ])
  end
end
