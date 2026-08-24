import { Controller } from "@hotwired/stimulus"

// Mounts Stripe's Payment Element, which draws the card fields and every wallet
// enabled on the account (Apple Pay, Google Pay, Link, PayPal). The card number
// never touches this page: the inputs live in Stripe's iframe.
export default class extends Controller {
  static targets = ["element", "submit", "submitLabel", "error"]
  static values = { key: String, secret: String, returnUrl: String, locale: String }

  async connect() {
    const stripeGlobal = await this.waitForStripe()
    if (!stripeGlobal) return this.fail("Le module de paiement n'a pas pu etre charge.")

    this.stripe = stripeGlobal(this.keyValue)
    this.elements = this.stripe.elements({
      clientSecret: this.secretValue,
      // Stripe draws its own labels, so it has to be told the storefront language.
      locale: this.hasLocaleValue && this.localeValue ? this.localeValue : "fr",
      appearance: this.appearance
    })

    this.payment = this.elements.create("payment", { layout: "tabs" })
    this.payment.on("ready", () => this.ready())
    this.payment.on("loaderror", (event) => this.fail(event?.error?.message))
    this.payment.mount(this.elementTarget)
  }

  disconnect() {
    this.payment?.unmount()
  }

  async submit(event) {
    event.preventDefault()
    if (this.busy) return

    this.setBusy(true)
    this.clearError()

    const { error } = await this.stripe.confirmPayment({
      elements: this.elements,
      confirmParams: { return_url: this.returnUrlValue }
    })

    // Reaching this line means the payment did not go through; on success Stripe
    // has already navigated away to the return URL.
    this.fail(error?.message)
    this.setBusy(false)
  }

  ready() {
    this.element.querySelector(".payment-form__loading")?.remove()
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  setBusy(busy) {
    this.busy = busy
    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = busy
    this.submitTarget.classList.toggle("is-busy", busy)
    if (this.hasSubmitLabelTarget) {
      this.submitLabelTarget.textContent = busy ? "Paiement en cours…" : this.originalLabel
    }
  }

  fail(message) {
    if (!message || !this.hasErrorTarget) return

    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    if (!this.hasErrorTarget) return

    this.errorTarget.hidden = true
    this.errorTarget.textContent = ""
  }

  get originalLabel() {
    this._label ||= this.hasSubmitLabelTarget ? this.submitLabelTarget.textContent.trim() : ""
    return this._label
  }

  // The script tag sits in <head>, but a Turbo visit can run this controller
  // before the browser finished fetching it.
  waitForStripe(attempts = 40) {
    return new Promise((resolve) => {
      const poll = (left) => {
        if (window.Stripe) return resolve(window.Stripe)
        if (left <= 0) return resolve(null)
        setTimeout(() => poll(left - 1), 75)
      }
      poll(attempts)
    })
  }

  // Matches the storefront: Inter, near-black actions, the same borders and radii.
  get appearance() {
    const styles = getComputedStyle(document.documentElement)
    const token = (name, fallback) => styles.getPropertyValue(name).trim() || fallback

    return {
      theme: "stripe",
      variables: {
        fontFamily: "Inter, ui-sans-serif, system-ui, sans-serif",
        colorPrimary: token("--stripe-accent", "#111111"),
        colorText: "#0f0f0f",
        colorTextSecondary: "#6b6b6b",
        colorDanger: "#c62828",
        borderRadius: "6px",
        spacingUnit: "4px"
      },
      rules: {
        ".Input": { border: "1px solid #dcdcd6", boxShadow: "none", padding: "12px" },
        ".Input:focus": { border: "1px solid #1f4ed8", boxShadow: "0 0 0 2px rgba(31, 78, 216, 0.18)" },
        ".Tab": { border: "1px solid #dcdcd6", boxShadow: "none" },
        ".Tab--selected": { border: "1px solid #111111", boxShadow: "0 0 0 1px #111111" },
        ".Label": { fontWeight: "500" }
      }
    }
  }
}
