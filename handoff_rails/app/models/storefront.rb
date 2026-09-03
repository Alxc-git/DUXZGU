# Copy and claims live in one place so views stay markup-only.
module Storefront
  PRICE          = "$39.99"
  PRICE_SUB      = "$33.99"
  RATING         = 4.9
  REVIEW_COUNT   = "2,300+"
  CUSTOMER_COUNT = "25,000+"

  CLAIMS = [
    { icon: "dumbbell", label: "5000 mg<br>creatine",      note: "Pure creatine monohydrate" },
    { icon: "candy",    label: "4 gummies<br>per serving", note: "Easy & convenient daily dose" },
    { icon: "package",  label: "130<br>gummies",           note: "32 servings per container" },
    { icon: "zap",      label: "Fast &amp;<br>convenient", note: "No mixing. No mess. Just results." }
  ].freeze

  BENEFITS = [
    { icon: "dumbbell",   label: "Build muscle",    note: "Lean mass & strength" },
    { icon: "zap",        label: "Boost power",     note: "Explosive performance" },
    { icon: "refresh-cw", label: "Faster recovery", note: "Train harder, recover smarter" }
  ].freeze

  TRUST = [
    { icon: "truck",        title: "Free shipping",     note: "On orders $60+" },
    { icon: "shield-check", title: "30-day guarantee",  note: "Love it or get a refund" },
    { icon: "lock",         title: "Secure checkout",   note: "Safe & encrypted" }
  ].freeze

  TICKER = [
    "5000 mg creatine monohydrate", "No mixing. No mess.", "130 gummies per jar",
    "32 servings", "Free shipping on $60+", "30-day money back guarantee",
    "Trusted by 25,000+ athletes", "4.9/5 from 2,300+ reviews"
  ].freeze

  PROS = ["5000 mg creatine monohydrate", "Delicious, easy-to-take gummies",
          "No mixing, no chalky taste", "Perfect for daily consistency"].freeze
  CONS = ["Usually less per serving", "Hard to mix, chalky taste",
          "Messy & inconvenient", "Easy to skip"].freeze

  HOW_TO_USE = [
    { n: "1", icon: "candy",    title: "Take 4 gummies", note: "One serving, any time of day." },
    { n: "2", icon: "calendar", title: "Be consistent",  note: "Daily use builds saturation." },
    { n: "3", icon: "dumbbell", title: "Feel the results", note: "More strength, power, recovery." }
  ].freeze

  REVIEWS = [
    { quote: "These gummies are a game changer. No mix, no mess, and they taste amazing.", name: "Jason T." },
    { quote: "More energy in my workouts and faster recovery. I feel the difference every day.", name: "Sarah M." },
    { quote: "Finally, creatine I enjoy! Great flavor and super easy to stay consistent.", name: "Mike R." }
  ].freeze

  FAQ = [
    { q: "How many gummies should I take?",
      a: "Four gummies daily — that is a full 5000 mg serving of creatine monohydrate." },
    { q: "When is the best time to take Creatine Jelly?",
      a: "Any time of day. Consistency matters far more than timing." },
    { q: "Is it safe to take every day?",
      a: "Yes. Creatine monohydrate is one of the most studied supplements there is, and daily use is what builds saturation." },
    { q: "What if I am not satisfied?",
      a: "Every order is covered by our 30-day money back guarantee." }
  ].freeze

  NAV = [["Home", "/"], ["Product", "/product"], ["Benefits", "/product#benefits"],
         ["Reviews", "/product#reviews"], ["FAQ", "/product#faq"]].freeze
end
