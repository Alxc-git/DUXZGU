import { Controller } from "@hotwired/stimulus"

// Keeps the displayed name, price and photo in sync with the selected colour.
// The selection itself travels with the form as `variant_id`; this is display only.
export default class extends Controller {
  static targets = ["name", "price", "compareAt", "image"]

  select(event) {
    const { name, price, compareAt, image } = event.target.dataset

    if (this.hasNameTarget && name) this.nameTarget.textContent = name
    if (this.hasPriceTarget && price) this.priceTarget.textContent = price

    if (this.hasCompareAtTarget) {
      this.compareAtTarget.textContent = compareAt || ""
      this.compareAtTarget.hidden = !compareAt
    }

    if (this.hasImageTarget && image) this.imageTarget.src = image
  }
}
