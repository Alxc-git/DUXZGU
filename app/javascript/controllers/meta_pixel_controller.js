import { Controller } from "@hotwired/stimulus"

// Raises the Meta Pixel events the server decided this page should send.
//
// The base snippet in the head initialises fbq once per visit and deliberately
// does not fire PageView: Turbo swaps the body instead of reloading, so a
// PageView from the snippet would only ever count the first page. This element
// lives in the body, so it reconnects on every navigation and PageView lands
// exactly once per page — including the first one.
export default class extends Controller {
  static values = { events: Array }

  connect() {
    // Turbo renders a cached preview before the real page and connects the
    // controllers a second time. A preview is not a page view.
    if (document.documentElement.hasAttribute("data-turbo-preview")) return
    // Blocked by an extension, or the customer has not accepted analytics.
    if (typeof window.fbq !== "function") return

    window.fbq("track", "PageView")

    this.eventsValue.forEach((event) => {
      if (event && event.name) window.fbq("track", event.name, event.data || {})
    })
  }
}
