import { Controller } from "@hotwired/stimulus"

const STUCK_AT = 24
const HIDE_AFTER = 260

export default class extends Controller {
  static classes = ["hidden", "stuck"]

  connect() {
    this.lastY = window.scrollY
    this.ticking = false
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    if (this.ticking) return

    this.ticking = true
    window.requestAnimationFrame(() => {
      this.update()
      this.ticking = false
    })
  }

  update() {
    const currentY = window.scrollY
    const scrollingDown = currentY > this.lastY
    // The drawer and the search panel are anchored to the header, so it has to
    // stay put while either of them is open.
    const pinned = document.body.classList.contains("has-open-menu")

    this.element.classList.toggle(this.stuckClass, currentY > STUCK_AT)
    this.element.classList.toggle(this.hiddenClass, !pinned && scrollingDown && currentY > HIDE_AFTER)

    this.lastY = Math.max(currentY, 0)
  }
}
