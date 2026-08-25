import { Controller } from "@hotwired/stimulus"

// Side-by-side colour comparison. Every card is rendered by the server; this only
// decides which are on screen, so the section still shows two colours with
// JavaScript switched off.
export default class extends Controller {
  static targets = ["chip", "card", "counter", "empty", "stage"]
  static classes = ["selected"]
  static values = { max: { type: Number, default: 3 } }

  connect() {
    this.selected = this.cardTargets.filter((card) => !card.hidden).map((card) => card.dataset.compareId)
    this.render()
  }

  toggle(event) {
    const id = String(event.params.id)
    const index = this.selected.indexOf(id)

    if (index >= 0) {
      // Never empty the stage from the last remaining chip.
      if (this.selected.length === 1) return
      this.selected.splice(index, 1)
    } else {
      // At the cap the oldest pick drops out, so a click always does something.
      if (this.selected.length >= this.maxValue) this.selected.shift()
      this.selected.push(id)
    }

    this.render()
  }

  render() {
    this.cardTargets.forEach((card) => {
      card.hidden = !this.selected.includes(card.dataset.compareId)
    })

    this.chipTargets.forEach((chip) => {
      const on = this.selected.includes(String(chip.dataset.compareIdParam))
      chip.setAttribute("aria-pressed", String(on))
      chip.classList.toggle(this.hasSelectedClass ? this.selectedClass : "is-picked", on)
    })

    if (this.hasStageTarget) {
      this.stageTarget.dataset.count = String(this.selected.length)
    }

    if (this.hasEmptyTarget) this.emptyTarget.hidden = this.selected.length > 0

    if (this.hasCounterTarget) {
      const n = this.selected.length
      this.counterTarget.textContent = `${n} couleur${n > 1 ? "s" : ""} sur ${this.maxValue}`
    }
  }
}
