import { Controller } from "@hotwired/stimulus"

const MIN = 1
const MAX = 99

export default class extends Controller {
  static targets = ["input"]

  increment() {
    this.setValue(this.value + 1)
  }

  decrement() {
    this.setValue(this.value - 1)
  }

  clamp() {
    this.setValue(this.value)
  }

  get value() {
    const parsed = Number.parseInt(this.inputTarget.value, 10)
    return Number.isNaN(parsed) ? MIN : parsed
  }

  // Dispatches `change` so a surrounding form (the cart lines) can react. Only on
  // a real change, otherwise clamp() -> setValue() -> change -> clamp() would loop.
  setValue(next) {
    const clamped = Math.min(Math.max(next, MIN), MAX)
    const previous = this.inputTarget.value
    this.inputTarget.value = clamped

    if (String(clamped) !== previous) {
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }
}
