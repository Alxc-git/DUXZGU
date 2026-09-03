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

  // Matches the storefront, which is dark: Stripe's own "night" base, then the
  // brand tokens read straight off :root so the fields never drift from the page.
  get appearance() {
    const styles = getComputedStyle(document.documentElement)
    const token = (name, fallback) => styles.getPropertyValue(name).trim() || fallback

    return {
      theme: "night",
      variables: {
        fontFamily: "Barlow, system-ui, -apple-system, sans-serif",
        colorPrimary: token("--accent", "#FF0F4E"),
        colorBackground: token("--ink-100", "#0B0B0E"),
        colorText: token("--gray-200", "#D8D8DC"),
        colorTextSecondary: token("--gray-400", "#8B8B95"),
        colorTextPlaceholder: token("--gray-500", "#65656F"),
        colorDanger: token("--negative", "#FF4646"),
        borderRadius: token("--radius-sm", "9px"),
        spacingUnit: "4px"
      },
      rules: {
        ".Input": {
          border: "1px solid rgba(255,255,255,.14)",
          boxShadow: "none",
          padding: "13px 14px"
        },
        ".Input:focus": {
          border: `1px solid ${token("--accent", "#FF0F4E")}`,
          boxShadow: "0 0 0 3px rgba(255,15,78,.16)"
        },
        ".Input--invalid": { border: `1px solid ${token("--negative", "#FF4646")}` },
        ".Tab": { border: "1px solid rgba(255,255,255,.14)", boxShadow: "none" },
        ".Tab:hover": { border: "1px solid rgba(255,15,78,.35)" },
        ".Tab--selected": {
          border: `1px solid ${token("--accent", "#FF0F4E")}`,
          boxShadow: "0 0 0 1px rgba(255,15,78,.45)"
        },
        ".Label": { fontWeight: "600", letterSpacing: ".02em" }
      }
    }
  }
}
