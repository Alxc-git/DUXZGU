import { Controller } from "@hotwired/stimulus"

// Mobile navigation drawer.
export default class extends Controller {
  static targets = ["panel", "openIcon", "closeIcon"]
  static classes = ["open"]

  connect() {
    this.close()
  }

  toggle() {
    this.expanded ? this.close() : this.open()
  }

  open() {
    this.setState(true)
  }

  close() {
    this.setState(false)
  }

  // Closing on navigation keeps the drawer from surviving a Turbo visit.
  disconnect() {
    document.body.classList.remove("has-open-menu")
  }

  setState(expanded) {
    this.expanded = expanded
    this.element.classList.toggle(this.openClass, expanded)
    document.body.classList.toggle("has-open-menu", expanded)

    const button = this.element.querySelector("[aria-expanded]")
    if (button) button.setAttribute("aria-expanded", String(expanded))

    if (this.hasOpenIconTarget) this.openIconTarget.hidden = expanded
    if (this.hasCloseIconTarget) this.closeIconTarget.hidden = !expanded
  }
}
