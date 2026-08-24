import { Controller } from "@hotwired/stimulus"

// Guards against a double submit creating two Stripe sessions. Buttons attached
// through the `form` attribute live outside the element, so they are collected
// separately from the ones nested inside it.
export default class extends Controller {
  connect() {
    this.element.addEventListener("submit", () => this.disableSubmitButtons())
  }

  disableSubmitButtons() {
    this.submitButtons.forEach((button) => { button.disabled = true })
  }

  get submitButtons() {
    const nested = Array.from(this.element.querySelectorAll("[type='submit']"))
    const detached = this.element.id
      ? Array.from(document.querySelectorAll(`[form="${this.element.id}"]`))
      : []

    return [...new Set([...nested, ...detached])]
  }
}
