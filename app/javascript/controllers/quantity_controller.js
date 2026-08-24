import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  clamp() {
    const value = Number.parseInt(this.inputTarget.value || "1", 10)
    this.inputTarget.value = Math.min(Math.max(value, 1), 99)
  }
}
