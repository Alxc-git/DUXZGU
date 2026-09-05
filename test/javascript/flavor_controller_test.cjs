const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")
const path = require("node:path")
const source = fs.readFileSync(path.join(__dirname, "../../app/javascript/controllers/flavor_controller.js"), "utf8")
  .replace(/^import .*\n/, "").replace("export default class", "globalThis.FlavorController = class")

function setup({ reduced = false, saveData = false, hero = false, mobile = false } = {}) {
  const window = new EventTarget()
  const location = new URL("https://shop.example/produit/creatine-jelly?qty=2#details")
  const history = { state: { turbo: { restorationIdentifier: "existing" } }, calls: [],
    replaceState(state, title, url) { this.calls.push({ state, url }) } }
  const preloads = []
  const context = vm.createContext({ Controller: class {}, window, location, history, URL,
    navigator: { connection: { saveData } }, matchMedia: query => ({ matches: query.includes('reduced-motion') ? reduced : mobile }),
    Image: class { constructor() { preloads.push(this) } } })
  vm.runInContext(source, context)
  const controller = new context.FlavorController()
  const forms = [{ value: "strawberry" }, { value: "strawberry" }]
  const unrelatedCartFlavor = { value: "raspberry" }
  const status = { textContent: "" }
  const text = { dataset: { flavorText: "name" } }
  const animations = []
  const image = { dataset: {}, animate() { const animation = { cancelled: false, cancel() { this.cancelled = true } }; animations.push(animation); return animation } }
  const heroImage = { dataset: { flavorImage: "hero" } }
  const mobileSource = {}
  const productLink = { href: "https://shop.example/produit/creatine-jelly?qty=3#faq", hasAttribute: () => false }
  const otherLink = { href: "https://other.example/produit/creatine-jelly", hasAttribute: () => false }
  const styles = new Map()
  controller.element = {
    querySelector: selector => selector === '[data-flavor-image="hero"]' ? (hero ? heroImage : null) : status,
    querySelectorAll(selector) {
      return {
        "[data-flavor-theme]": [{ style: { setProperty: (key, value) => styles.set(key, value) } }],
        "[data-flavor-choice]": [],
        "[data-flavor-image]": hero ? [heroImage, image] : [image],
        "[data-flavor-hero-mobile]": hero ? [mobileSource] : [],
        "[data-flavor-text]": [text],
        "form[data-flavor-purchase] input[name='flavor']": forms,
        "input[name='flavor']": [...forms, unrelatedCartFlavor],
        "a[href]": [productLink, otherLink]
      }[selector] || []
    }
  }
  Object.assign(controller, { selectedValue: "strawberry", productPathValue: "/produit/creatine-jelly",
    selectedLabelValue: "Selected", chooseLabelValue: "Choose",
    optionsValue: {
      strawberry: { name: "Strawberry", color: "red", spot: "red", src: "/red.webp", srcset: "/red-480.webp 480w",
        hero: { src: "/hero-red.webp", srcset: "/hero-red-1200.webp 1200w", mobileSrc: "/hero-mobile-red.webp", mobileSrcset: "/hero-mobile-red-480.webp 480w", focus: "72% center" } },
      blueberry: { name: "Blueberry", color: "blue", spot: "blue", src: "/blue.webp", srcset: "/blue-480.webp 480w",
        hero: { src: "/hero-blue.webp", srcset: "/hero-blue-1200.webp 1200w", mobileSrc: "/hero-mobile-blue.webp", mobileSrcset: "/hero-mobile-blue-480.webp 480w", focus: "72% center" } }
    } })
  controller.connect()
  function choose(slug, extra = {}) {
    const event = { currentTarget: { dataset: { flavorChoice: slug } }, prevented: false,
      preventDefault() { this.prevented = true }, ...extra }
    controller.choose(event)
    return event
  }
  return { controller, choose, forms, unrelatedCartFlavor, status, text, image, history, window, location,
    animations, productLink, otherLink, preloads, styles, heroImage, mobileSource }
}

test("selection updates purchase forms and images while preserving cart lines, quantity and anchors", () => {
  const page = setup()
  assert.equal(page.choose("blueberry").prevented, true)
  assert.deepEqual(page.forms.map(input => input.value), ["blueberry", "blueberry"])
  assert.equal(page.unrelatedCartFlavor.value, "raspberry")
  assert.equal(page.image.src, "/blue.webp")
  assert.equal(page.image.srcset, "/blue-480.webp 480w")
  assert.equal(page.text.textContent, "Blueberry")
  assert.equal(page.status.textContent, "Blueberry — Selected")
  assert.equal(page.styles.get("--active-flavor"), "blue")
  assert.equal(page.productLink.href, "https://shop.example/produit/creatine-jelly?qty=3&flavor=blueberry#faq")
  assert.equal(page.otherLink.href, "https://other.example/produit/creatine-jelly")
  assert.equal(page.history.calls[0].url.href, "https://shop.example/produit/creatine-jelly?qty=2&flavor=blueberry#details")
  assert.equal(page.history.calls[0].state, page.history.state)
})

test("modifier clicks and unknown flavors retain native link behavior", () => {
  const page = setup()
  assert.equal(page.choose("blueberry", { ctrlKey: true }).prevented, false)
  assert.equal(page.choose("unknown").prevented, false)
  assert.equal(page.history.calls.length, 0)
})

test("repeat selection does not animate or rewrite history and reduced motion is respected", () => {
  const page = setup({ reduced: true })
  page.choose("blueberry")
  page.choose("blueberry")
  assert.equal(page.animations.length, 0)
  assert.equal(page.history.calls.length, 1)
})

test("history restores the current selection and disconnect cleans animations and listener", () => {
  const page = setup()
  page.choose("blueberry")
  page.window.dispatchEvent(new Event("popstate"))
  assert.equal(page.controller.selectedValue, "strawberry")
  assert.equal(page.animations[0].cancelled, true)
  page.choose("blueberry")
  page.controller.disconnect()
  assert.equal(page.animations[1].cancelled, true)
  page.window.dispatchEvent(new Event("popstate"))
  assert.equal(page.controller.selectedValue, "blueberry")
})

test("preloading happens once per flavor and respects data saving", () => {
  for (const saveData of [false, true]) {
    const page = setup({ saveData })
    const event = { currentTarget: { dataset: { flavorChoice: "blueberry" } } }
    page.controller.preload(event)
    page.controller.preload(event)
    assert.equal(page.preloads.length, saveData ? 0 : 1)
  }
})

test("hero desktop and mobile artwork change independently of the product cards", () => {
  const page = setup({ hero: true })
  page.choose("blueberry")
  assert.equal(page.heroImage.src, "/hero-blue.webp")
  assert.equal(page.heroImage.srcset, "/hero-blue-1200.webp 1200w")
  assert.equal(page.mobileSource.srcset, "/hero-mobile-blue-480.webp 480w")
  assert.equal(page.image.src, "/blue.webp")
  assert.equal(page.styles.get("--hero-focus"), "72% center")
})

test("hero preload uses the scene suited to the viewport", () => {
  for (const mobile of [false, true]) {
    const page = setup({ hero: true, mobile })
    page.controller.preload({ currentTarget: { dataset: { flavorChoice: "blueberry" } } })
    assert.equal(page.preloads[0].src, mobile ? "/hero-mobile-blue.webp" : "/hero-blue.webp")
  }
})
