# Copy and claims for the storefront.
#
# The text lives in config/locales; only the structure is here — which icon goes
# with which line, and in what order. Everything is a method rather than a
# constant because a constant would freeze whichever language happened to be
# active when the class was first loaded.
module Storefront
  BRAND          = "DUWZGU"
  PRODUCT_NAME   = "Creatine Jelly"
  PRICE          = "$34.99"

  module_function

  def t(key, **args) = I18n.t("store.#{key}", **args)

  def claims
    [
      { icon: "dumbbell", label: t("claims.creatine_label_html"),    note: t("claims.creatine_note") },
      { icon: "candy",    label: t("claims.serving_label_html"),     note: t("claims.serving_note") },
      { icon: "package",  label: t("claims.count_label_html"),       note: t("claims.count_note") },
      { icon: "zap",      label: t("claims.convenient_label_html"),  note: t("claims.convenient_note") }
    ]
  end

  def benefits
    [
      { icon: "dumbbell",   label: t("benefits.muscle"),   note: t("benefits.muscle_note") },
      { icon: "zap",        label: t("benefits.power"),    note: t("benefits.power_note") },
      { icon: "refresh-cw", label: t("benefits.recovery"), note: t("benefits.recovery_note") }
    ]
  end

  def trust
    [
      { icon: "truck",        title: t("trust.shipping"),  note: t("trust.shipping_note") },
      { icon: "shield-check", title: t("trust.guarantee"), note: t("trust.guarantee_note") },
      { icon: "lock",         title: t("trust.secure"),    note: t("trust.secure_note") }
    ]
  end

  def ticker
    %w[one two three four five six].map { |k| t("ticker.#{k}") }
  end

  def pros = %w[one two three four].map { |k| t("pros.#{k}") }
  def cons = %w[one two three four].map { |k| t("cons.#{k}") }

  def how_to_use
    [
      { n: "1", icon: "candy",    title: t("how_to_use.one"),   note: t("how_to_use.one_note") },
      { n: "2", icon: "calendar", title: t("how_to_use.two"),   note: t("how_to_use.two_note") },
      { n: "3", icon: "dumbbell", title: t("how_to_use.three"), note: t("how_to_use.three_note") }
    ]
  end

  def faq
    (1..4).map { |i| { q: t("faq.q#{i}"), a: t("faq.a#{i}") } }
  end

  # Only render reviews once a source of real customer feedback is connected.
  def reviews = []

  def nav
    [
      [ t("nav.home"),     :root ],
      [ t("nav.product"),  :product ],
      [ t("nav.benefits"), :benefits ],
      [ t("nav.reviews"),  :reviews ],
      [ t("nav.faq"),      :faq ]
    ]
  end
end
