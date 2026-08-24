import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static classes = ["open"]

  connect() {
    this.sync()
  }

  toggle(event) {
    const item = event.currentTarget.closest("details")
    if (!item || item.open) return

    this.itemTargets.forEach((target) => {
      if (target !== item) target.removeAttribute("open")
    })
  }

  sync() {
    this.itemTargets.forEach((item) => {
      item.classList.toggle(this.openClass, item.open)
    })
  }
}
