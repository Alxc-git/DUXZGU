// Drives the real Stimulus controller through the connect() sequences Turbo
// produces, and counts what reaches fbq.
//
// No browser: the controller is loaded as it ships, with the Stimulus base class
// and the two globals it touches replaced by stubs. What is under test is its own
// guard logic, which is where a duplicate PageView would come from.
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync, writeFileSync, mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const SOURCE = "app/javascript/controllers/meta_pixel_controller.js"
const scratch = mkdtempSync(join(tmpdir(), "meta-pixel-"))
let loads = 0

// A fresh import stands for a full page load: the module scope, and so the
// guards, start over. Turbo navigations reuse one import.
async function loadController() {
  const source = readFileSync(SOURCE, "utf8")
    .replace(/^import \{ Controller \}.*$/m, "class Controller {}")
  const path = join(scratch, `controller-${loads++}.mjs`)
  writeFileSync(path, source)

  return (await import(`file://${path}`)).default
}

function browser() {
  const calls = []
  let preview = false

  globalThis.document = {
    documentElement: { hasAttribute: (name) => preview && name === "data-turbo-preview" }
  }
  globalThis.window = { location: { href: "https://luxtimestyle.com/" }, fbq: (...args) => calls.push(args) }

  return {
    calls,
    pageViews: () => calls.filter(([verb, name]) => verb === "track" && name === "PageView").length,
    named: (name) => calls.filter(([, event]) => event === name),
    visit: (href) => { globalThis.window.location.href = href },
    preview: (value) => { preview = value },
    removeFbq: () => { delete globalThis.window.fbq }
  }
}

function render(Controller, events = []) {
  const controller = new Controller()
  controller.eventsValue = events
  controller.connect()
}

test("a full page load raises exactly one PageView", async () => {
  const page = browser()
  const Controller = await loadController()

  render(Controller)

  assert.equal(page.pageViews(), 1)
  assert.deepEqual(page.calls[0], [ "track", "PageView" ])
})

test("a Turbo preview followed by the real render raises one PageView", async () => {
  const page = browser()
  const Controller = await loadController()

  page.preview(true)
  render(Controller)
  page.preview(false)
  render(Controller)

  assert.equal(page.pageViews(), 1)
})

test("two connects for the same url raise one PageView even with no preview flag", async () => {
  const page = browser()
  const Controller = await loadController()

  render(Controller)
  render(Controller)
  render(Controller)

  assert.equal(page.pageViews(), 1)
})

test("two controller instances in the same DOM raise one PageView", async () => {
  const page = browser()
  const Controller = await loadController()

  const first = new Controller()
  const second = new Controller()
  first.eventsValue = []
  second.eventsValue = []
  first.connect()
  second.connect()

  assert.equal(page.pageViews(), 1)
})

test("each Turbo navigation raises its own PageView", async () => {
  const page = browser()
  const Controller = await loadController()

  render(Controller)
  page.visit("https://luxtimestyle.com/panier")
  render(Controller)
  page.visit("https://luxtimestyle.com/commande")
  render(Controller)

  assert.equal(page.pageViews(), 3)
})

test("navigating back to a page already seen raises a PageView again", async () => {
  const page = browser()
  const Controller = await loadController()

  render(Controller)
  page.visit("https://luxtimestyle.com/panier")
  render(Controller)
  page.visit("https://luxtimestyle.com/")
  render(Controller)

  assert.equal(page.pageViews(), 3)
})

test("a full reload of the same url raises a PageView again", async () => {
  const page = browser()

  render(await loadController(), [])
  // A reload re-imports the module, which is what resets the guard.
  render(await loadController(), [])

  assert.equal(page.pageViews(), 2)
})

test("PageView is always tracked, never trackCustom", async () => {
  const page = browser()
  const Controller = await loadController()

  render(Controller, [ { name: "ViewContent", data: { value: 79.99 } } ])

  assert.equal(page.calls.filter(([verb]) => verb === "trackCustom").length, 0)
  assert.ok(page.calls.every(([verb]) => verb === "track"))
})

test("page events ride along once, and repeat only when they really differ", async () => {
  const page = browser()
  const Controller = await loadController()
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

test("sends nothing when the pixel never loaded", async () => {
  const page = browser()
  const Controller = await loadController()
  page.removeFbq()

  assert.doesNotThrow(() => render(Controller, [ { name: "ViewContent", data: {} } ]))
  assert.equal(page.calls.length, 0)
})
