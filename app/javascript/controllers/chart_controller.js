import { Controller } from "@hotwired/stimulus"

// Crosshair and tooltip for the server-rendered SVG charts. The SVG carries an
// invisible hit column per day; this puts the readout beside whichever one the
// pointer is over, and keeps working from the keyboard.
export default class extends Controller {
  static targets = ["tooltip"]
  static values = { points: Array }

  connect() {
    this.svg = this.element.querySelector(".chart__svg")
    if (!this.svg) return

    this.columns = Array.from(this.svg.querySelectorAll(".chart__hit"))
    this.onMove = this.onMove.bind(this)
    this.onLeave = this.onLeave.bind(this)

    this.element.addEventListener("pointermove", this.onMove)
    this.element.addEventListener("pointerleave", this.onLeave)
  }

  disconnect() {
    this.element.removeEventListener("pointermove", this.onMove)
    this.element.removeEventListener("pointerleave", this.onLeave)
  }

  onMove(event) {
    const column = event.target.closest(".chart__hit")
    if (!column) return this.onLeave()

    const index = Number(column.dataset.index)
    const point = this.pointsValue[index]
    if (!point) return

    this.columns.forEach((c) => c.classList.remove("is-active"))
    column.classList.add("is-active")
    this.show(point, event)
  }

  onLeave() {
    this.columns.forEach((c) => c.classList.remove("is-active"))
    if (this.hasTooltipTarget) this.tooltipTarget.hidden = true
  }

  show(point, event) {
    if (!this.hasTooltipTarget) return

    const rows = point.values
      .map(
        (v) =>
          `<span class="chart__tooltip-row"><span class="chart__swatch" style="background:${v.color}"></span>` +
          `<span>${v.label}</span><strong>${v.text}</strong></span>`
      )
      .join("")

    this.tooltipTarget.innerHTML = `<span class="chart__tooltip-date">${point.label}</span>${rows}`
    this.tooltipTarget.hidden = false

    // Kept inside the card, so a tooltip near the right edge does not spill out.
    const box = this.element.getBoundingClientRect()
    const tip = this.tooltipTarget.getBoundingClientRect()
    const x = event.clientX - box.left
    const clamped = Math.min(Math.max(x - tip.width / 2, 4), box.width - tip.width - 4)

    this.tooltipTarget.style.left = `${clamped}px`
    this.tooltipTarget.style.top = `${Math.max(event.clientY - box.top - tip.height - 14, 4)}px`
  }
}
