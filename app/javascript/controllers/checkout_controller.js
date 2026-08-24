import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("submit", () => {
      this.element.querySelectorAll("[type='submit']").forEach((button) => {
        button.disabled = true
      })
    })
  }
}
