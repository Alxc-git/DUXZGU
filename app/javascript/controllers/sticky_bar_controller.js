import { Controller } from "@hotwired/stimulus"

// Reveals the sticky buy bar once the main buy form has scrolled past.
export default class extends Controller {
  static classes = ["visible"]
  static values = { anchor: String }

  connect() {
    const anchor = document.querySelector(this.anchorValue)
    if (!anchor) return

    this.element.hidden = false
    this.observer = new IntersectionObserver(
      ([entry]) => this.element.classList.toggle(this.visibleClass, !entry.isIntersecting),
      { rootMargin: "0px 0px -20% 0px" }
    )
    this.observer.observe(anchor)
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
