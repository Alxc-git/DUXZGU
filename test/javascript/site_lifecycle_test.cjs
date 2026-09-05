const test = require("node:test");
const assert = require("node:assert/strict");
const vm = require("node:vm");
const fs = require("node:fs");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../../app/assets/javascripts/site.js"), "utf8");

function setup({ reduced = false, targets = [], clocks = [], progress = null, nativeScroll = false } = {}) {
  const document = new EventTarget();
  document.body = {};
  document.hidden = false;
  document.querySelector = selector => selector === "[data-scroll-progress]" ? progress : null;
  document.scrollingElement = { scrollTop: 0, scrollHeight: 2800, clientHeight: 800 };
  document.querySelectorAll = selector => {
    if (selector.startsWith(".reveal")) return targets;
    if (selector === "[data-cutoff]") return clocks;
    return [];
  };
  const media = new Map();
  const matchMedia = query => {
    if (!media.has(query)) {
      const preference = new EventTarget();
      preference.matches = query.includes("reduced-motion") ? reduced : false;
      media.set(query, preference);
    }
    return media.get(query);
  };
  const observers = [];
  class IntersectionObserver {
    constructor(callback) { this.callback = callback; this.disconnected = false; observers.push(this); }
    observe() {}
    unobserve() {}
    disconnect() { this.disconnected = true; }
  }
  const resizeObservers = [];
  class ResizeObserver {
    constructor(callback) { this.callback = callback; this.disconnected = false; resizeObservers.push(this); }
    observe() {}
    disconnect() { this.disconnected = true; }
  }
  const frames = new Map();
  let frameCount = 0;
  const window = Object.assign(new EventTarget(), { matchMedia, innerHeight: 800,
    IntersectionObserver, ResizeObserver, CSS: { supports: () => nativeScroll } });
  const timers = new Set();
  let timerCount = 0;
  const context = vm.createContext({ document, window,
    IntersectionObserver, ResizeObserver, AbortController, console, Date,
    setInterval() { const id = ++timerCount; timers.add(id); return id; },
    clearInterval(id) { timers.delete(id); },
    setTimeout, clearTimeout,
    requestAnimationFrame(callback) { const id = ++frameCount; frames.set(id, callback); return id; },
    cancelAnimationFrame(id) { frames.delete(id); } });
  vm.runInContext(source, context);
  return { document, window, timers, observers, resizeObservers, frames, matchMedia,
    flushFrames() { const pending = [...frames.values()]; frames.clear(); pending.forEach(callback => callback()); },
    get timerCount() { return timerCount; },
    fire(name) { document.dispatchEvent(new Event(name)); } };
}

function revealTarget(top) {
  const classes = new Set(["reveal"]);
  return { classList: { add: name => classes.add(name), contains: name => classes.has(name) },
    setAttribute() {}, getBoundingClientRect: () => ({ top }) };
}

test("first load only starts one timer; Turbo navigation cleans and restores it", () => {
  const clock = { textContent: "" };
  const el = { querySelector: () => clock, getAttribute: () => new Date(Date.now() + 3600000).toISOString() };
  const page = setup({ clocks: [el] });
  page.fire("DOMContentLoaded");
  page.fire("turbo:load");
  assert.equal(page.timerCount, 1);
  assert.equal(page.timers.size, 1);
  page.fire("turbo:before-cache");
  assert.equal(page.timers.size, 0);
  page.fire("turbo:load");
  assert.equal(page.timerCount, 2);
  assert.equal(page.timers.size, 1);
  page.fire("turbo:before-render");
  assert.equal(page.timers.size, 0);
});

test("visible content never gets hidden; pending reveals are visible in cached pages", () => {
  const above = revealTarget(100);
  const below = revealTarget(1000);
  const page = setup({ targets: [above, below] });
  page.fire("turbo:load");
  assert.equal(above.classList.contains("is-in"), true);
  assert.equal(above.classList.contains("is-reveal-pending"), false);
  assert.equal(below.classList.contains("is-reveal-pending"), true);
  page.fire("turbo:before-cache");
  assert.equal(below.classList.contains("is-in"), true);
  assert.equal(page.observers.every(o => o.disconnected), true);
});

test("reduced motion shows every section without waiting for scrolling", () => {
  const below = revealTarget(1000);
  const page = setup({ reduced: true, targets: [below] });
  page.fire("turbo:load");
  assert.equal(below.classList.contains("is-in"), true);
  assert.equal(below.classList.contains("is-reveal-pending"), false);
  assert.equal(page.observers.length, 0);
});

test("changing reduced motion while reading releases all pending sections", () => {
  const below = revealTarget(1000);
  const page = setup({ targets: [below] });
  page.fire("turbo:load");
  const preference = page.matchMedia("(prefers-reduced-motion: reduce)");
  preference.matches = true;
  preference.dispatchEvent(new Event("change"));
  assert.equal(below.classList.contains("is-in"), true);
  assert.equal(page.observers.every(o => o.disconnected), true);
});

function progressIndicator() {
  return { style: { removeProperty(name) { delete this[name]; } } };
}

test("reading progress handles scrolling, changed page height and overscroll with reduced motion", () => {
  const progress = progressIndicator();
  const page = setup({ progress, reduced: true });
  const scroller = page.document.scrollingElement;
  page.fire("turbo:load");
  assert.equal(progress.style.transform, "scaleX(0)");
  scroller.scrollTop = 1000;
  page.window.dispatchEvent(new Event("scroll"));
  page.window.dispatchEvent(new Event("scroll"));
  assert.equal(page.frames.size, 1, "scroll events share one scheduled frame");
  page.flushFrames();
  assert.equal(progress.style.transform, "scaleX(0.5)");

  scroller.scrollHeight = 4800;
  page.resizeObservers[0].callback();
  page.flushFrames();
  assert.equal(progress.style.transform, "scaleX(0.25)");
  for (const [top, expected] of [[5000, "scaleX(1)"], [-100, "scaleX(0)"]]) {
    scroller.scrollTop = top;
    page.window.dispatchEvent(new Event("scroll"));
    page.flushFrames();
    assert.equal(progress.style.transform, expected);
  }
  scroller.scrollHeight = scroller.clientHeight;
  page.window.dispatchEvent(new Event("resize"));
  page.flushFrames();
  assert.equal(progress.style.transform, "scaleX(0)", "a short page never divides by zero");
});

test("reading progress releases frames and listeners before caching and resumes at restored position", () => {
  const progress = progressIndicator();
  const page = setup({ progress });
  page.fire("DOMContentLoaded");
  page.fire("turbo:load");
  assert.equal(page.resizeObservers.length, 1);
  page.fire("turbo:before-cache");
  assert.equal(page.frames.size, 0);
  assert.equal(progress.style.transform, undefined);
  assert.equal(page.resizeObservers[0].disconnected, true);
  page.window.dispatchEvent(new Event("scroll"));
  assert.equal(page.frames.size, 0);

  page.document.scrollingElement.scrollTop = 1000;
  page.fire("turbo:load");
  assert.equal(progress.style.transform, "scaleX(0.5)");
  assert.equal(page.resizeObservers.length, 2);
  page.fire("turbo:before-render");
  assert.equal(page.frames.size, 0);
  assert.equal(page.resizeObservers[1].disconnected, true);
});

test("native scroll timelines need no JavaScript progress observers or frames", () => {
  const progress = progressIndicator();
  const page = setup({ progress, nativeScroll: true });
  page.fire("turbo:load");
  assert.equal(progress.style.transform, undefined);
  assert.equal(page.frames.size, 0);
  assert.equal(page.resizeObservers.length, 0);
});
