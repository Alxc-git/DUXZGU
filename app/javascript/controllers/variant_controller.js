import { Controller } from "@hotwired/stimulus"

// Single source of truth for the selected option. The radios carry the data, the
// thumbnails and swatches are just two views of the same choice, and every price,
// name and image target on the page repaints from whichever one the visitor uses.
export default class extends Controller {
  static targets = ["name", "price", "compareAt", "image", "heroImage", "thumb", "swatch"]

  select(event) {
    this.apply(event.target)
  }

  // Thumbnails sit outside the form, so they check the matching radio first.
  pick(event) {
    const id = event.currentTarget.dataset.variantId
    const radio = this.element.querySelector(`input[name="variant_id"][value="${id}"]`)
    if (!radio) return

    radio.checked = true
    this.apply(radio)
  }

  apply(radio) {
    const { variantId, name, price, compareAt, image, hero, details } = radio.dataset

    this.nameTargets.forEach((target) => { if (name) target.textContent = name })
    this.priceTargets.forEach((target) => { if (price) target.textContent = price })

    this.compareAtTargets.forEach((target) => {
      target.textContent = compareAt || ""
      target.hidden = !compareAt
    })

    if (image) {
      this.imageTargets.forEach((target) => { target.src = image })
    }

    if (hero) {
      this.heroImageTargets.forEach((target) => { target.src = hero })
    }

    this.markActive(this.thumbTargets, variantId)
    this.markActive(this.swatchTargets, variantId)
    this.rememberVariant(variantId)

    // The gallery sits inside this controller's element, so the event goes through
    // window rather than bubbling, which only ever travels upwards.
    this.dispatch("change", {
      target: window,
      prefix: "variant",
      detail: { variantId, name, hero, image, details: this.parseDetails(details) }
    })
  }

  parseDetails(value) {
    if (!value) return []

    try {
      return JSON.parse(value)
    } catch (_error) {
      return []
    }
  }

  markActive(elements, variantId) {
    elements.forEach((element) => {
      element.classList.toggle("is-active", element.dataset.variantId === variantId)
    })
  }

  rememberVariant(variantId) {
    if (!variantId || !this.element.querySelector("[data-controller~='gallery']")) return

    const url = new URL(window.location.href)
    url.searchParams.set("option", variantId)
    window.history.replaceState(window.history.state, "", url)
  }
}
