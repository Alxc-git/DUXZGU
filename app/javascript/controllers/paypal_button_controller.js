import { Controller } from "@hotwired/stimulus"

// Renders the PayPal buttons and drives the two server calls around them.
//
// The SDK has to come from PayPal's own domain and cannot be bundled, so it is
// loaded once on demand and shared by any button on the page.
export default class extends Controller {
  static targets = ["container", "error"]
  static values = { clientId: String, currency: String, createUrl: String, captureUrl: String }

  async connect() {
    if (!this.clientIdValue) return

    try {
      const paypal = await this.loadSdk()
      paypal
        .Buttons({
          style: { layout: "vertical", shape: "rect", color: "gold", label: "paypal", height: 48 },
          createOrder: () => this.createOrder(),
          onApprove: (data) => this.capture(data.orderID),
          onCancel: () => this.showError("Paiement PayPal annule. Votre commande vous attend toujours."),
          onError: () => this.showError("PayPal n'a pas pu traiter le paiement. Reessayez ou payez par carte.")
        })
        .render(this.containerTarget)
    } catch (_error) {
      this.showError("Le bouton PayPal n'a pas pu se charger. Le paiement par carte reste disponible.")
    }
  }

  loadSdk() {
    if (window.paypal) return Promise.resolve(window.paypal)
    if (window.__paypalSdkPromise) return window.__paypalSdkPromise

    window.__paypalSdkPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      const params = new URLSearchParams({
        "client-id": this.clientIdValue,
        currency: this.currencyValue || "CAD",
        intent: "capture",
        components: "buttons",
        "disable-funding": "credit,card"
      })
      script.src = `https://www.paypal.com/sdk/js?${params}`
      script.onload = () => (window.paypal ? resolve(window.paypal) : reject(new Error("SDK absent")))
      script.onerror = () => reject(new Error("SDK injoignable"))
      document.head.appendChild(script)
    })

    return window.__paypalSdkPromise
  }

  async createOrder() {
    this.clearError()
    const data = await this.post(this.createUrlValue)
    if (!data.id) throw new Error(data.error || "Creation refusee")

    return data.id
  }

  async capture(paypalOrderId) {
    const data = await this.post(this.captureUrlValue, { paypal_order_id: paypalOrderId })

    if (data.redirect_url) {
      window.location.assign(data.redirect_url)
      return
    }

    // The money may well have been taken even though the answer is an error, so
    // the customer is told to check rather than invited to pay a second time.
    this.showError(
      data.error ||
        "Le paiement a ete approuve mais la confirmation a echoue. Ne payez pas de nouveau, ecrivez-nous."
    )
  }

  async post(url, body = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify(body)
    })

    return response.json().catch(() => ({}))
  }

  showError(message) {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    if (this.hasErrorTarget) this.errorTarget.hidden = true
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
