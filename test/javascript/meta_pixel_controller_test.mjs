// Drives the real Stimulus controller through the connect() sequences Turbo
// produces, and counts what reaches fbq.
//
// No browser: the controller is loaded as it ships, with the Stimulus base class
// and the two globals it touches replaced by stubs. What is under test is its own
// guard logic, which is where a duplicate PageView would come from.
//
// The guards live on `window`, so a fresh window is what a full page reload is
// here — and loading the module twice stands for two copies of the controller
// ending up on the same page.
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, writeFileSync, mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const SOURCE = "app/javascript/controllers/meta_pixel_controller.js"
const scratch = mkdtempSync(join(tmpdir(), "meta-pixel-"))
let copies = 0

async function loadController() {
  const source = readFileSync(SOURCE, "utf8")
    .replace(/^import \{ Controller \}.*$/m, "class Controller {}")
  const path = join(scratch, `controller-${copies++}.mjs`)
  writeFileSync(path, source)

  return (await import(`file://${path}`)).default
}

// A fresh window: a first visit, or a full reload.
function load(href = "https://example.com/") {
  const calls = []
  let preview = false

  globalThis.document = {
    documentElement: { hasAttribute: (name) => preview && name === "data-turbo-preview" }
  }
  globalThis.window = { location: { href }, fbq: (...args) => calls.push(args) }

  return {
    calls,
    pageViews: () => calls.filter(([verb, name]) => verb === "track" && name === "PageView").length,
    named: (name) => calls.filter(([, event]) => event === name),
    visit: (to) => { globalThis.window.location.href = to },
    preview: (value) => { preview = value },
    removeFbq: () => { delete globalThis.window.fbq }
  }
}

function render(Controller, events = []) {
  const controller = new Controller()
  controller.eventsValue = events
  controller.connect()
}

const Controller = await loadController()

test("a full page load raises exactly one PageView", () => {
  const page = load()

  render(Controller)

  assert.equal(page.pageViews(), 1)
  assert.deepEqual(page.calls[0], [ "track", "PageView" ])
})

test("a Turbo preview followed by the real render raises one PageView", () => {
  const page = load()

  page.preview(true)
  render(Controller)
  page.preview(false)
  render(Controller)

  assert.equal(page.pageViews(), 1)
})

test("repeated connects for the same url raise one PageView", () => {
  const page = load()

  render(Controller)
  render(Controller)
  render(Controller)

  assert.equal(page.pageViews(), 1)
})

test("two controller instances on one page raise one PageView", () => {
  const page = load()

  const first = new Controller()
  const second = new Controller()
  first.eventsValue = []
  second.eventsValue = []
  first.connect()
  second.connect()

  assert.equal(page.pageViews(), 1)
})

test("even two copies of the controller module raise one PageView", async () => {
  const page = load()
  const other = await loadController()

  render(Controller)
  render(other)

  assert.equal(page.pageViews(), 1)
})

test("each Turbo navigation raises its own PageView", () => {
  const page = load()

  render(Controller)
  page.visit("https://example.com/panier")
  render(Controller)
  page.visit("https://example.com/commande")
  render(Controller)

  assert.equal(page.pageViews(), 3)
})

test("navigating back to a page already seen raises a PageView again", () => {
  const page = load()

  render(Controller)
  page.visit("https://example.com/panier")
  render(Controller)
  page.visit("https://example.com/")
  render(Controller)

  assert.equal(page.pageViews(), 3)
})

test("a full reload of the same url raises a PageView again", () => {
  const first = load()
  render(Controller)

  // A reload builds a new window, which is where the guards live.
  const second = load()
  render(Controller)

  assert.equal(first.pageViews(), 1)
  assert.equal(second.pageViews(), 1)
})

test("PageView is always tracked, never trackCustom", () => {
  const page = load()

  render(Controller, [ { name: "ViewContent", data: { value: 79.99 } } ])

  assert.equal(page.calls.filter(([verb]) => verb === "trackCustom").length, 0)
  assert.ok(page.calls.every(([verb]) => verb === "track"))
})

test("page events ride along once, and repeat only when they really differ", () => {
  const page = load()
  const viewContent = [ { name: "ViewContent", data: { value: 79.99 } } ]

  render(Controller, viewContent)
  render(Controller, viewContent)

  assert.equal(page.named("ViewContent").length, 1)
  assert.equal(page.pageViews(), 1)

  // /panier renders again after the add, this time carrying an AddToCart. The
  // event is real; the PageView is not.
  render(Controller, [ { name: "AddToCart", data: { num_items: 2 } } ])

  assert.equal(page.named("AddToCart").length, 1)
  assert.equal(page.pageViews(), 1)
})

test("sends nothing when the pixel never loaded", () => {
  const page = load()
  page.removeFbq()

  assert.doesNotThrow(() => render(Controller, [ { name: "ViewContent", data: {} } ]))
  assert.equal(page.calls.length, 0)
})
