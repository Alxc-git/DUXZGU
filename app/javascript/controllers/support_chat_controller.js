import { Controller } from "@hotwired/stimulus"

// Versioned: bumping it retires conversations stored under the previous
// greeting, which would otherwise keep showing the old opening line forever.
const STORAGE_KEY = "luxtime.support-chat.v2"
// Says who it is, sets the expectation, and states the one thing the customer
// cannot guess: an order lookup needs the reference AND the email, because that
// pair is what the server verifies before showing anything.
const GREETING =
  "Bonjour ! Je suis l'assistant LUXTIME, disponible 24/7. " +
  "Pour suivre une commande, donnez-moi sa reference (LX-XXXXXXXX) et le courriel utilise a l'achat. " +
  "Sinon, choisissez une question ci-dessous."

export default class extends Controller {
  static targets = ["panel", "messages", "input", "toggle", "submit", "badge", "suggestions"]
  static values = { url: String }
  static classes = ["open"]

  connect() {
    this.history = this.restore()

    if (this.history.length === 0) {
      this.history = [{ role: "assistant", content: GREETING }]
      this.persist()
    }

    this.history.forEach((item) => this.draw(item.role, item.content))
    this.unread = this.readUnread()
    this.renderBadge()
    this.renderSuggestions()

    // The visual viewport shrinks when the keyboard opens; the layout viewport
    // does not. Following it is what keeps the compose box above the keys.
    this.onViewport = () => this.fitToViewport()
    window.visualViewport?.addEventListener("resize", this.onViewport)
    window.visualViewport?.addEventListener("scroll", this.onViewport)
  }

  disconnect() {
    window.visualViewport?.removeEventListener("resize", this.onViewport)
    window.visualViewport?.removeEventListener("scroll", this.onViewport)
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.element.classList.add(this.openClass)
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.clearUnread()
    this.scrollToLatest()
    this.fitToViewport()

    // Deliberately not focused on a phone: focusing raises the keyboard before
    // the customer has read anything.
    if (!this.isPhone) this.inputTarget.focus()
  }

  close() {
    this.panelTarget.hidden = true
    this.element.classList.remove(this.openClass)
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.blur()
    this.panelTarget.style.removeProperty("height")
  }

  keydown(event) {
    if (event.key === "Escape") return this.close()
    // Enter sends on a desktop keyboard; on a phone it has to insert a newline,
    // because the same key is the one people press to dismiss the keyboard.
    if (event.key !== "Enter" || event.shiftKey || this.isPhone) return

    event.preventDefault()
    this.submit(event)
  }

  grow() {
    const field = this.inputTarget
    field.style.height = "auto"
    field.style.height = `${Math.min(field.scrollHeight, 112)}px`
  }

  useSuggestion(event) {
    this.inputTarget.value = event.params.prompt
    this.submit(event)
  }

  async submit(event) {
    event.preventDefault()
    if (this.busy) return

    const message = this.inputTarget.value.trim()
    if (!message) return

    this.inputTarget.value = ""
    this.grow()
    this.append("user", message)
    this.setBusy(true)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ message, history: this.history.slice(-6) })
      })
      const data = await response.json()
      this.append("assistant", data.reply || "Je n'ai pas pu repondre pour le moment.")
    } catch (_error) {
      this.append("assistant", "Le chat est indisponible pour le moment. Reessayez dans quelques instants.")
    } finally {
      this.setBusy(false)
    }
  }

  // ---------------------------------------------------------------- rendering

  append(role, content) {
    this.draw(role, content)
    this.history.push({ role, content })
    this.history = this.history.slice(-20)
    this.persist()

    if (role === "assistant" && this.panelTarget.hidden) {
      this.unread += 1
      this.writeUnread()
      this.renderBadge()
    }
  }

  draw(role, content) {
    const item = document.createElement("div")
    item.className = `support-chat__message support-chat__message--${role}`

    const bubble = document.createElement("p")
    // textContent, never innerHTML: the reply is model output and is treated as
    // untrusted text.
    bubble.textContent = content
    item.appendChild(bubble)

    this.messagesTarget.appendChild(item)
    this.scrollToLatest()
  }

  setBusy(busy) {
    this.busy = busy
    this.submitTarget.disabled = busy
    this.renderSuggestions()

    if (busy) {
      const holder = document.createElement("div")
      holder.className = "support-chat__message support-chat__message--assistant"
      holder.dataset.typing = "true"
      holder.innerHTML = '<span class="support-chat__typing"><span></span><span></span><span></span></span>'
      this.messagesTarget.appendChild(holder)
      this.scrollToLatest()
    } else {
      this.messagesTarget.querySelector("[data-typing]")?.remove()
    }
  }

  // The chips are a starting point, not a permanent menu: once the conversation
  // is under way they only take room from the answers.
  renderSuggestions() {
    if (!this.hasSuggestionsTarget) return

    this.suggestionsTarget.hidden = Boolean(this.busy) || this.history.some((item) => item.role === "user")
  }

  scrollToLatest() {
    requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
  }

  // Pins the sheet to the visible area while the keyboard is up.
  fitToViewport() {
    if (this.panelTarget.hidden || !this.isPhone) return

    const viewport = window.visualViewport
    if (!viewport) return

    this.panelTarget.style.height = `${Math.round(viewport.height * 0.9)}px`
    this.scrollToLatest()
  }

  // -------------------------------------------------------------------- badge

  renderBadge() {
    if (!this.hasBadgeTarget) return

    this.badgeTarget.hidden = this.unread === 0
    this.badgeTarget.textContent = String(Math.min(this.unread, 9))
    this.toggleTarget.setAttribute(
      "aria-label",
      this.unread > 0 ? `Ouvrir l'assistant, ${this.unread} message non lu` : "Ouvrir l'assistant"
    )
  }

  clearUnread() {
    this.unread = 0
    this.writeUnread()
    this.renderBadge()
  }

  // ------------------------------------------------------------------ storage

  restore() {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY)
      const parsed = raw ? JSON.parse(raw) : null
      return Array.isArray(parsed) ? parsed.slice(-20) : []
    } catch (_error) {
      return []
    }
  }

  persist() {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(this.history))
    } catch (_error) {
      // A full or blocked storage must never stop the chat working.
    }
  }

  readUnread() {
    try {
      return Number(sessionStorage.getItem(`${STORAGE_KEY}.unread`) || "1")
    } catch (_error) {
      return 1
    }
  }

  writeUnread() {
    try {
      sessionStorage.setItem(`${STORAGE_KEY}.unread`, String(this.unread))
    } catch (_error) {
      // ignored, see persist()
    }
  }

  get isPhone() {
    return window.matchMedia("(max-width: 560px)").matches
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
