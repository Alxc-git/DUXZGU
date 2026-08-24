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

  setValue(next) {
    this.inputTarget.value = Math.min(Math.max(next, MIN), MAX)
  }
}
