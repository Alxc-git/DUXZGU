import { Controller } from "@hotwired/stimulus"

// Filters the pre-rendered result rows in place: the store sells one product in a
// handful of options, so there is nothing to fetch.
export default class extends Controller {
  static targets = ["overlay", "input", "result", "empty"]

  open() {
    this.overlayTarget.hidden = false
    document.body.classList.add("has-open-menu")
    requestAnimationFrame(() => this.inputTarget.focus())
  }

  close() {
    this.overlayTarget.hidden = true
    document.body.classList.remove("has-open-menu")
    this.inputTarget.value = ""
    this.filter()
  }

  // Only a click on the backdrop itself closes; clicks inside the panel bubble here too.
  backdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  keydown(event) {
    if (event.key === "Escape") this.close()
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    let matches = 0

    this.resultTargets.forEach((result) => {
      const hit = !query || (result.dataset.searchTerms || "").includes(query)
      result.hidden = !hit
      if (hit) matches += 1
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = matches > 0
  }

  disconnect() {
    document.body.classList.remove("has-open-menu")
  }
}
