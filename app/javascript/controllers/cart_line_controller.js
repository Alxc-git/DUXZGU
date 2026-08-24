import { Controller } from "@hotwired/stimulus"

// Saves a quantity change straight away, so the cart never shows a total that
// disagrees with the stepper next to it.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
