import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "luxtime:wishlist"

// A local favourite: there is no customer account yet, so the choice is kept in
// this browser rather than pretending it was saved anywhere else.
export default class extends Controller {
  static values = { key: String }
  static classes = ["saved"]

  connect() {
    this.render(this.saved.includes(this.keyValue))
  }

  toggle() {
    const saved = this.saved
    const next = saved.includes(this.keyValue)
      ? saved.filter((entry) => entry !== this.keyValue)
      : [...saved, this.keyValue]

    this.write(next)
    this.render(next.includes(this.keyValue))
  }

  render(isSaved) {
    this.element.classList.toggle(this.savedClass, isSaved)
    this.element.setAttribute("aria-pressed", String(isSaved))
    this.element.setAttribute("aria-label", isSaved ? "Retirer des favoris" : "Ajouter aux favoris")
  }

  get saved() {
    try {
      const raw = JSON.parse(window.localStorage.getItem(STORAGE_KEY))
      return Array.isArray(raw) ? raw : []
    } catch {
      return []
    }
  }

  // Private browsing and blocked storage should not break the button.
  write(entries) {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(entries))
    } catch {
      // Ignored: the button still reflects the choice for this page view.
    }
  }
}
