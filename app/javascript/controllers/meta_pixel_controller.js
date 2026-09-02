import { Controller } from "@hotwired/stimulus"

// Envoie les événements Meta décidés par le serveur.
//
// Les gardes sont stockés sur window plutôt qu'au niveau du module.
// Ainsi, même si Stimulus charge/connecte accidentellement deux instances,
// une même navigation ne peut produire qu'un seul PageView.
//
// Un vrai reload recrée window, donc le même URL sera correctement
// compté comme une nouvelle PageView.

export default class extends Controller {
  static values = { events: Array }

  connect() {
    // Turbo peut connecter les controllers une première fois sur
    // un aperçu en cache. Ce n'est pas une vraie page vue.
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    // Pixel absent : consentement refusé, bloqueur, etc.
    if (typeof window.fbq !== "function") return

    this.trackPageView()
    this.trackPageEvents()
  }

  trackPageView() {
    const url = window.location.href

    // GLOBAL à toute la page, même avec plusieurs instances/modules.
    if (window.__storefrontMetaLastPageViewUrl === url) return

    window.__storefrontMetaLastPageViewUrl = url

    window.fbq("track", "PageView")
  }

  trackPageEvents() {
    const events = this.eventsValue

    if (!events || events.length === 0) return

    // Set global partagé entre toutes les instances du controller.
    window.__storefrontMetaEventKeys ||= new Set()

    events.forEach((event) => {
      if (!event || !event.name) return

      const key = [
        window.location.href,
        event.name,
        JSON.stringify(event.data || {})
      ].join("|")

      if (window.__storefrontMetaEventKeys.has(key)) return

      window.__storefrontMetaEventKeys.add(key)

      window.fbq("track", event.name, event.data || {})
    })
  }
}
