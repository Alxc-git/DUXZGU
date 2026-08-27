import { Controller } from "@hotwired/stimulus"

// Drives the product gallery: thumbnails, dots and the zoom overlay all point at
// one index, and a colour change resets the rail back to the watch itself.
export default class extends Controller {
  static targets = ["stage", "thumb", "dot", "lightbox", "lightboxImage"]
  static classes = ["active"]

  connect() {
    this.variantId = this.element.dataset.galleryVariantId || "default"
    this.index = 0
    this.onVariantChange = this.onVariantChange.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    window.addEventListener("variant:change", this.onVariantChange)
    window.addEventListener("keydown", this.onKeydown)
    this.select(this.storedIndex(), { persist: false })
  }

  disconnect() {
    window.removeEventListener("variant:change", this.onVariantChange)
    window.removeEventListener("keydown", this.onKeydown)
    document.body.classList.remove("has-open-menu")
  }

  show(event) {
    this.select(Number(event.params.index))
    this.revealStage()
  }

  select(index, { persist = true } = {}) {
    const thumb = this.thumbTargets[index]
    if (!thumb) return

    this.index = index
    const { gallerySrc, galleryAlt, galleryFit } = thumb.dataset

    if (gallerySrc && this.hasStageTarget) {
      this.stageTarget.src = gallerySrc
      this.stageTarget.alt = galleryAlt || ""
      // The editorial shot is lit against black and fills the frame; the detail
      // packshots sit on white and have to keep their margin.
      this.stageTarget.classList.toggle("gallery__image--cover", galleryFit === "cover")
    }

    this.thumbTargets.forEach((element, position) => {
      element.classList.toggle(this.activeClass, position === index)
    })

    this.dotTargets.forEach((dot, position) => {
      dot.classList.toggle(this.activeClass, position === index)
      dot.setAttribute("aria-selected", String(position === index))
    })

    if (persist) this.storeIndex(index)
  }

  // The colour picker owns the first slide's photo, so it has to be re-pointed
  // whenever the customer switches colour.
  onVariantChange(event) {
    const first = this.thumbTargets[0]
    if (!first) return

    const { variantId, hero, name, details = [] } = event.detail || {}
    this.variantId = variantId || "default"
    this.element.dataset.galleryVariantId = this.variantId
    if (hero) first.dataset.gallerySrc = hero
    if (name) first.dataset.galleryAlt = name

    const firstImage = first.querySelector("img")
    if (firstImage) {
      if (hero) firstImage.src = hero
      if (name) firstImage.alt = name
    }

    this.thumbTargets.slice(1).forEach((thumb, index) => {
      const detail = details[index]
      const item = thumb.closest("li")

      if (item) item.hidden = !detail
      if (!detail) return

      thumb.dataset.gallerySrc = detail.src
      thumb.dataset.galleryAlt = detail.alt || name || ""

      const image = thumb.querySelector("img")
      if (image) {
        image.src = detail.src
        image.alt = detail.alt || ""
      }
    })

    this.dotTargets.slice(1).forEach((dot, index) => {
      dot.hidden = !details[index]
    })

    this.select(this.storedIndex(), { persist: false })
  }

  revealStage() {
    if (!this.hasStageTarget || !window.matchMedia("(max-width: 767px)").matches) return

    const stage = this.stageTarget.closest(".gallery__stage")
    if (!stage) return

    const behavior = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"
    requestAnimationFrame(() => stage.scrollIntoView({ behavior, block: "start" }))
  }

  storedIndex() {
    try {
      const value = Number.parseInt(window.sessionStorage.getItem(this.storageKey()), 10)
      return Number.isInteger(value) && this.thumbTargets[value] ? value : 0
    } catch (_error) {
      return 0
    }
  }

  storeIndex(index) {
    try {
      window.sessionStorage.setItem(this.storageKey(), String(index))
    } catch (_error) {
      // Safari private mode may disable session storage; the gallery still works.
    }
  }

  storageKey() {
    return `luxtime:gallery:${window.location.pathname}:${this.variantId}`
  }

  zoom() {
    if (!this.hasLightboxTarget || !this.hasStageTarget) return

    this.lightboxImageTarget.src = this.stageTarget.src
    this.lightboxImageTarget.alt = this.stageTarget.alt
    this.lightboxTarget.hidden = false
    document.body.classList.add("has-open-menu")
  }

  closeZoom() {
    if (!this.hasLightboxTarget) return

    this.lightboxTarget.hidden = true
    document.body.classList.remove("has-open-menu")
  }

  onKeydown(event) {
    if (this.hasLightboxTarget && !this.lightboxTarget.hidden) {
      if (event.key === "Escape") this.closeZoom()
      return
    }

    // Arrow keys belong to whatever field has focus before they belong to the rail.
    if (event.target.closest("input, textarea, select, [contenteditable]")) return

    if (event.key === "ArrowRight") this.select(Math.min(this.index + 1, this.thumbTargets.length - 1))
    if (event.key === "ArrowLeft") this.select(Math.max(this.index - 1, 0))
  }
}
