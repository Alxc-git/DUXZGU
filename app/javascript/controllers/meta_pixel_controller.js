import { Controller } from "@hotwired/stimulus"

// Raises the Meta Pixel events the server decided this page should send.
//
// The base snippet in the head initialises fbq once per visit and deliberately
// does not fire PageView: Turbo swaps the body instead of reloading, so a
// PageView from the snippet would only ever count the first page of a visit.
// This element lives in the body, so it reconnects on every navigation and
// PageView lands exactly once per page — including the first one.

// Module scope, so the guards survive the controller being torn down and rebuilt
// by a Turbo render. A full reload re-imports the module and resets them, which
// is what makes a genuine reload of the same URL count again.
let lastPageViewUrl = null
let lastEventsKey = null

export default class extends Controller {
  static values = { events: Array }

  connect() {
    // Turbo renders a cached preview before the real page and connects the
    // controllers a second time. A preview is not a page view.
    if (document.documentElement.hasAttribute("data-turbo-preview")) return
    // Blocked by an extension, or the customer has not accepted analytics.
    if (typeof window.fbq !== "function") return

    this.trackPageView()
    this.trackPageEvents()
  }

  // One PageView per URL, whatever else happens. Belt and braces on top of the
  // preview guard above: any second connect() for a page already counted — a
  // re-render, a restored snapshot, a stray second instance in the DOM — finds
  // the URL already recorded and sends nothing.
  trackPageView() {
    const url = window.location.href
    if (lastPageViewUrl === url) return

    lastPageViewUrl = url
    window.fbq("track", "PageView")
  }

  // Keyed on the payload as well as the URL, unlike PageView: the same page can
  // legitimately be rendered twice with different events — /panier carries an
  // AddToCart only on the render that follows the add — and that second one is a
  // real event, not a duplicate.
  trackPageEvents() {
    const events = this.eventsValue
    if (events.length === 0) return

    const key = `${window.location.href}|${JSON.stringify(events)}`
    if (lastEventsKey === key) return

    lastEventsKey = key
    events.forEach((event) => {
      if (event && event.name) window.fbq("track", event.name, event.data || {})
    })
  }
}
