import { Controller } from "@hotwired/stimulus"

// The real links remain usable without JavaScript. A selection only updates the
// current product's artwork and purchase forms; existing cart lines stay intact.
export default class extends Controller {
  static values = { options: Object, selected: String, productPath: String, selectedLabel: String, chooseLabel: String }

  connect() {
    this.preloaded = new Set()
    this.animations = []
    this.onHistory = () => this.apply(new URL(location.href).searchParams.get("flavor") || "strawberry")
    window.addEventListener("popstate", this.onHistory)
  }

  disconnect() {
    window.removeEventListener("popstate", this.onHistory)
    this.animations.forEach(animation => animation.cancel())
  }

  preload(event) {
    const slug = event.currentTarget.dataset.flavorChoice
    if (this.preloaded.has(slug) || navigator.connection?.saveData) return
    const option = this.optionsValue[slug]
    if (!option) return
    this.preloaded.add(slug)
    const hero = this.element.querySelector('[data-flavor-image="hero"]')
    const mobile = matchMedia("(max-width: 899px)").matches
    const image = new Image()
    image.sizes = hero ? "100vw" : "(min-width: 900px) 50vw, 100vw"
    image.srcset = hero ? (mobile ? option.hero.mobileSrcset : option.hero.srcset) : option.srcset
    image.src = hero ? (mobile ? option.hero.mobileSrc : option.hero.src) : option.src
  }

  choose(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button > 0) return
    const slug = event.currentTarget.dataset.flavorChoice
    if (!this.optionsValue[slug]) return
    event.preventDefault()
    if (slug === this.selectedValue) return
    this.apply(slug, true)
    const url = new URL(location.href)
    url.searchParams.set("flavor", slug)
    history.replaceState(history.state, "", url)
  }

  apply(slug, animate = false) {
    const option = this.optionsValue[slug]
    if (!option) return
    this.selectedValue = slug
    this.animations.forEach(animation => animation.cancel())
    this.animations = []
    this.element.querySelectorAll("[data-flavor-theme]").forEach(element => {
      element.style.setProperty("--active-flavor", option.color)
      element.style.setProperty("--active-spot", option.spot)
      if (option.hero) element.style.setProperty("--hero-focus", option.hero.focus)
    })
    this.element.querySelectorAll("[data-flavor-choice]").forEach(element => {
      const selected = element.dataset.flavorChoice === slug
      element.classList.toggle("is-selected", selected)
      selected ? element.setAttribute("aria-current", "true") : element.removeAttribute("aria-current")
      element.querySelectorAll("[data-flavor-check]").forEach(check => { check.hidden = !selected })
      element.querySelectorAll("[data-flavor-choice-label]").forEach(label => {
        label.textContent = selected ? this.selectedLabelValue : this.chooseLabelValue
        label.classList.toggle("btn--primary", selected)
        label.classList.toggle("btn--secondary", !selected)
      })
    })
    this.element.querySelectorAll("[data-flavor-hero-mobile]").forEach(source => {
      source.srcset = option.hero.mobileSrcset
    })
    this.element.querySelectorAll("[data-flavor-image]").forEach(image => {
      const artwork = image.dataset.flavorImage === "hero" ? option.hero : option
      image.srcset = artwork.srcset
      image.src = artwork.src
      image.alt = `${option.name} · DUWZGU Creatine Jelly`
      if (animate && !matchMedia("(prefers-reduced-motion: reduce)").matches && image.animate) {
        this.animations.push(image.animate([{opacity: .35}, {opacity: 1}], {duration: 240, easing: "ease-out"}))
      }
    })
    this.element.querySelectorAll("[data-flavor-text]").forEach(element => {
      element.textContent = option[element.dataset.flavorText] || ""
    })
    this.element.querySelectorAll("form[data-flavor-purchase] input[name='flavor']").forEach(input => { input.value = slug })
    this.element.querySelectorAll("a[href]").forEach(link => {
      if (link.hasAttribute("data-flavor-choice")) return
      if (link.hasAttribute("data-flavor-zoom")) { link.href = option.src; return }
      const url = new URL(link.href, location.origin)
      if (url.origin !== location.origin || url.pathname !== this.productPathValue) return
      url.searchParams.set("flavor", slug)
      link.href = url.toString()
    })
    const status = this.element.querySelector("[data-flavor-status]")
    if (status) status.textContent = `${option.name} — ${this.selectedLabelValue}`
  }
}
