import { Controller } from "@hotwired/stimulus"

// Search-as-you-type on the shipping address. The customer types the start of
// the street line, picks a row, and the city, province, postal code and country
// are filled in for them — the four fields a wrong delivery usually comes from.
//
// The lookup goes through our own endpoint rather than a geocoder directly, so
// no API key ever reaches the browser and the results stay inside the countries
// the store ships to.
export default class extends Controller {
  static targets = ["query", "list", "status", "city", "province", "postalCode", "country", "next"]

  static values = {
    url: String,
    detailsUrl: String,
    minLength: { type: Number, default: 3 },
    delay: { type: Number, default: 250 },
    statusLabel: String
  }

  connect() {
    this.states = new Map()
    // The browser's own history dropdown would cover ours, and it knows none of
    // the postal codes.
    this.queryTargets.forEach((input) => {
      input.setAttribute("autocomplete", "off")
      this.stateFor(this.kindFor(input))
    })
    // Turbo restores the cached DOM on a back navigation, dropdown included, so
    // the list starts from nothing every time the controller comes up.
    this.listTargets.forEach((list) => list.replaceChildren())
    this.closeAll()
  }

  disconnect() {
    this.states.forEach((state) => {
      clearTimeout(state.timer)
      state.aborter?.abort()
    })
  }

  // ------------------------------------------------------------------ lookup

  search(event) {
    if (this.suppressSearch) return

    const input = event.currentTarget
    const kind = this.kindFor(input)
    const state = this.stateFor(kind)
    clearTimeout(state.timer)
    const query = input.value.trim()

    if (query.length < this.minLengthValue) return this.close(kind)

    state.timer = setTimeout(() => this.load(query, kind), this.delayValue)
  }

  async load(query, kind) {
    this.abort(kind)
    const state = this.stateFor(kind)
    state.aborter = new AbortController()

    try {
      const response = await fetch(this.endpoint(query, kind), {
        headers: { Accept: "application/json" },
        signal: state.aborter.signal
      })

      if (!response.ok) return this.close(kind)

      const payload = await response.json()
      this.render(payload.suggestions || [], kind, payload.attribution)
    } catch (error) {
      // An aborted request is the next keystroke arriving, not a failure.
      if (error.name !== "AbortError") this.close(kind)
    }
  }

  endpoint(query, kind) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    url.searchParams.set("mode", kind)
    url.searchParams.set("session_token", this.sessionToken(kind))

    if (this.hasCountryTarget && this.countryTarget.value) {
      url.searchParams.set("country", this.countryTarget.value)
    }

    // A postal code or city already entered sharply narrows short street
    // prefixes such as "700 rue go" without requiring location permission.
    if (kind === "address") {
      if (this.hasCityTarget && this.cityTarget.value) url.searchParams.set("city", this.cityTarget.value)
      if (this.hasProvinceTarget && this.provinceTarget.value) url.searchParams.set("province", this.provinceTarget.value)
      if (this.hasPostalCodeTarget && this.postalCodeTarget.value) {
        url.searchParams.set("postal_code", this.postalCodeTarget.value)
      }
    }

    return url
  }

  abort(kind) {
    const state = this.stateFor(kind)
    state.aborter?.abort()
    state.aborter = null
  }

  // ------------------------------------------------------------------ render

  render(suggestions, kind, attribution = null) {
    const state = this.stateFor(kind)
    const list = this.listFor(kind)
    state.suggestions = suggestions
    state.activeIndex = -1
    list.replaceChildren()

    if (suggestions.length === 0) return this.close(kind)

    suggestions.forEach((suggestion, index) => {
      list.append(this.option(suggestion, index, kind))
    })

    if (attribution) list.append(this.attribution(attribution))

    this.open(kind)
  }

  option(suggestion, index, kind) {
    const item = document.createElement("li")
    const list = this.listFor(kind)

    item.className = "autocomplete__option"
    item.id = `${list.id}-option-${index}`
    item.dataset.index = index
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", "false")
    item.textContent = suggestion.label
    // mousedown rather than click: the blur a click starts with would close the
    // list out from under the pointer before the click ever landed.
    item.addEventListener("mousedown", (event) => {
      event.preventDefault()
      void this.choose(kind, index)
    })

    return item
  }

  attribution(label) {
    const item = document.createElement("li")
    item.className = "autocomplete__attribution"
    item.setAttribute("role", "presentation")
    item.textContent = label
    return item
  }

  open(kind) {
    this.listTargets.forEach((list) => {
      const otherKind = this.kindFor(list)
      if (otherKind !== kind) this.close(otherKind, false)
    })

    this.listFor(kind).hidden = false
    this.queryFor(kind).setAttribute("aria-expanded", "true")
    this.announce(`${this.stateFor(kind).suggestions.length} ${this.statusLabelValue}`)
  }

  close(kind, announce = true) {
    const list = this.listFor(kind)
    const query = this.queryFor(kind)
    if (!list || !query) return

    list.hidden = true
    query.setAttribute("aria-expanded", "false")
    query.removeAttribute("aria-activedescendant")
    this.stateFor(kind).activeIndex = -1
    if (announce) this.announce("")
  }

  closeAll() {
    this.listTargets.forEach((list) => this.close(this.kindFor(list), false))
    this.announce("")
  }

  announce(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  // --------------------------------------------------------------- keyboard

  navigate(event) {
    const kind = this.kindFor(event.currentTarget)
    const state = this.stateFor(kind)

    if (this.listFor(kind).hidden) {
      if (event.key === "ArrowDown") this.search(event)
      return
    }

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.move(kind, 1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.move(kind, -1)
        break
      case "Enter":
        // Only swallow the Enter that picks a row; with nothing highlighted it
        // still submits the form the way the customer expects.
        if (state.activeIndex >= 0) {
          event.preventDefault()
          this.choose(kind, state.activeIndex)
        }
        break
      case "Escape":
      case "Tab":
        this.close(kind)
        break
    }
  }

  move(kind, step) {
    const state = this.stateFor(kind)
    const count = this.optionsFor(kind).length
    if (count === 0) return

    state.activeIndex = (state.activeIndex + step + count) % count
    this.highlight(kind)
  }

  highlight(kind) {
    const state = this.stateFor(kind)
    const query = this.queryFor(kind)

    this.optionsFor(kind).forEach((option, index) => {
      const active = index === state.activeIndex
      option.setAttribute("aria-selected", active ? "true" : "false")
      if (active) {
        option.scrollIntoView({ block: "nearest" })
        query.setAttribute("aria-activedescendant", option.id)
      }
    })
  }

  // A click inside the list is already handled on mousedown; anything else that
  // takes the focus away means the customer is done with the dropdown.
  blur(event) {
    const input = event.currentTarget
    const kind = this.kindFor(input)

    if (kind === "postal") this.formatCompletePostalCode(input)

    setTimeout(() => {
      if (document.activeElement !== input) this.close(kind)
    }, 0)
  }

  // ------------------------------------------------------------------ select

  async choose(kind, index) {
    let suggestion = this.stateFor(kind).suggestions[index]
    if (!suggestion) return

    if (suggestion.place_id) {
      suggestion = await this.resolve(suggestion.place_id, kind)
      if (!suggestion) return this.close(kind)
    }

    if (kind === "address") {
      this.fill(this.queryFor(kind), suggestion.line1)
    } else if (this.hasPostalCodeTarget) {
      this.fill(this.postalCodeTarget, suggestion.postal_code)
    }

    if (this.hasCityTarget) this.fill(this.cityTarget, suggestion.city)
    if (this.hasProvinceTarget) this.fill(this.provinceTarget, suggestion.province)
    if (kind === "address" && this.hasPostalCodeTarget && !this.hasCompletePostalCode(this.postalCodeTarget.value)) {
      this.fill(this.postalCodeTarget, suggestion.postal_code)
    }
    if (this.hasCountryTarget) this.selectCountry(suggestion.country)

    this.close(kind)
    this.rotateSessionToken(kind)
    // The only thing left to type is the apartment number, so send them there.
    if (kind === "address" && this.hasNextTarget) this.nextTarget.focus()
  }

  async resolve(placeId, kind) {
    this.abort(kind)
    const state = this.stateFor(kind)
    state.aborter = new AbortController()

    const url = new URL(this.detailsUrlValue, window.location.origin)
    url.searchParams.set("place_id", placeId)
    url.searchParams.set("session_token", this.sessionToken(kind))
    if (this.hasCountryTarget && this.countryTarget.value) {
      url.searchParams.set("country", this.countryTarget.value)
    }

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: state.aborter.signal
      })
      if (!response.ok) return null

      const payload = await response.json()
      return payload.suggestion || null
    } catch (error) {
      if (error.name !== "AbortError") return null
    }
  }

  fill(field, value) {
    if (!value) return

    this.suppressSearch = true
    field.value = value
    // Removed and re-added around a forced reflow, otherwise picking a second
    // address leaves the class in place and the tint never plays again.
    field.classList.remove("input--autofilled")
    void field.offsetWidth
    field.classList.add("input--autofilled")
    field.addEventListener("animationend", () => field.classList.remove("input--autofilled"), { once: true })
    // Anything else watching the field — validation, Turbo, the browser's own
    // autofill heuristics — only reacts to a real event.
    field.dispatchEvent(new Event("input", { bubbles: true }))
    field.dispatchEvent(new Event("change", { bubbles: true }))
    this.suppressSearch = false
  }

  compactPostalCode(value) {
    return value.toUpperCase().replace(/[^A-Z0-9]/g, "")
  }

  hasCompletePostalCode(value) {
    return /^[ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTVWXYZ]\d[ABCEGHJ-NPRSTVWXYZ]\d$/.test(
      this.compactPostalCode(value)
    )
  }

  formatCompletePostalCode(field) {
    if (!this.hasCompletePostalCode(field.value)) return

    const code = this.compactPostalCode(field.value)
    field.value = `${code.slice(0, 3)} ${code.slice(3)}`
  }

  // The country is a select limited to where the store ships, so a suggestion
  // from anywhere else leaves the customer's own choice alone.
  selectCountry(code) {
    if (!code) return

    const option = Array.from(this.countryTarget.options).find((item) => item.value === code)
    if (option) this.fill(this.countryTarget, option.value)
  }

  kindFor(element) {
    return element?.dataset.autocompleteKind || "address"
  }

  stateFor(kind) {
    if (!this.states.has(kind)) {
      this.states.set(kind, { suggestions: [], activeIndex: -1, sessionToken: this.newSessionToken() })
    }
    return this.states.get(kind)
  }

  sessionToken(kind) {
    return this.stateFor(kind).sessionToken
  }

  rotateSessionToken(kind) {
    this.stateFor(kind).sessionToken = this.newSessionToken()
  }

  newSessionToken() {
    return window.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`
  }

  queryFor(kind) {
    return this.queryTargets.find((input) => this.kindFor(input) === kind)
  }

  listFor(kind) {
    return this.listTargets.find((list) => this.kindFor(list) === kind)
  }

  optionsFor(kind) {
    return Array.from(this.listFor(kind)?.querySelectorAll(".autocomplete__option") || [])
  }
}
