// Progressive enhancement only — every screen works without it.
let activeBody = null;
let pageEvents = null;
const pageCleanups = [];
const onPageCleanup = (callback) => pageCleanups.push(callback);

// Older browsers get the same reading indicator. Batch scroll/resize updates
// into one frame, and release everything when Turbo replaces or caches the page.
const startScrollProgress = () => {
  const fill = document.querySelector("[data-scroll-progress]");
  if (!fill || window.CSS?.supports("animation-timeline: scroll(root block)")) return;

  const scroller = document.scrollingElement || document.documentElement;
  let frame = null;
  const update = () => {
    frame = null;
    const distance = scroller.scrollHeight - scroller.clientHeight;
    const progress = distance > 0 ? Math.min(1, Math.max(0, scroller.scrollTop / distance)) : 0;
    fill.style.transform = `scaleX(${progress})`;
  };
  const schedule = () => {
    if (frame === null) frame = requestAnimationFrame(update);
  };
  const options = { passive: true, signal: pageEvents.signal };
  window.addEventListener("scroll", schedule, options);
  window.addEventListener("resize", schedule, options);
  window.addEventListener("pageshow", schedule, options);
  document.addEventListener("load", schedule, { capture: true, signal: pageEvents.signal });
  const observer = "ResizeObserver" in window ? new ResizeObserver(schedule) : null;
  observer?.observe(document.body);
  update();
  schedule();
  onPageCleanup(() => {
    if (frame !== null) cancelAnimationFrame(frame);
    observer?.disconnect();
    fill.style.removeProperty("transform");
  });
};

document.addEventListener("click", (event) => {
  // Mobile nav sheet
  const toggle = event.target.closest("[data-nav-toggle]");
  if (toggle) {
    const sheet = toggle.closest("[data-nav]").querySelector("[data-nav-sheet]");
    const open = sheet.classList.toggle("is-open");
    toggle.setAttribute("aria-expanded", String(open));
    return;
  }

  // FAQ accordion
  const accBtn = event.target.closest("[data-accordion-toggle]");
  if (accBtn) {
    const item = accBtn.closest(".accordion__item");
    const open = item.classList.contains("is-open");
    item.closest("[data-accordion]").querySelectorAll(".accordion__item")
      .forEach((el) => {
        el.classList.remove("is-open");
        el.querySelector("[data-accordion-toggle]")?.setAttribute("aria-expanded", "false");
      });
    if (!open) item.classList.add("is-open");
    accBtn.setAttribute("aria-expanded", String(!open));
    return;
  }

  // Flash dismissal
  const flashClose = event.target.closest("[data-flash-close]");
  if (flashClose) {
    flashClose.closest("[data-flash]")?.remove();
    return;
  }

  // Quantity stepper
  const step = event.target.closest("[data-qty-inc], [data-qty-dec]");
  if (step) {
    const wrap = step.closest("[data-qty]");
    const val = wrap.querySelector("[data-qty-val]");
    const next = parseInt(val.textContent, 10) + (step.hasAttribute("data-qty-inc") ? 1 : -1);
    val.textContent = Math.min(99, Math.max(1, next));
  }
});

// Price odometers. The reels sit at 0 until this runs, so rolling them is just
// adding a class; an observer holds the roll back until the price is on screen.
const rollOdometers = (root = document) => {
  const reels = root.querySelectorAll(".odo:not([data-odo-rolled])");
  if (!reels.length) return;

  const roll = (el) => {
    el.setAttribute("data-odo-rolled", "");
    el.classList.add("is-rolling");
  };

  if (!("IntersectionObserver" in window) || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    reels.forEach(roll);
    return;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      roll(entry.target);
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.4 });

  reels.forEach((el) => observer.observe(el));
  onPageCleanup(() => observer.disconnect());
};


// --- Dispatch countdown ----------------------------------------------------
// The cutoff instant is rendered by the server; this only ticks the label down.
const startCutoffClocks = (root = document) => {
  root.querySelectorAll("[data-cutoff]").forEach((el) => {
    const clock = el.querySelector("[data-cutoff-clock]");
    if (!clock) return;

    const target = new Date(el.getAttribute("data-cutoff")).getTime();
    if (!Number.isFinite(target)) return;
    const tick = () => {
      const left = Math.max(0, Math.floor((target - Date.now()) / 1000));
      if (left === 0) { clearInterval(timer); el.hidden = true; return; }
      const h = Math.floor(left / 3600);
      const m = Math.floor((left % 3600) / 60);
      const s = left % 60;
      clock.textContent = h > 0 ? `${h}h ${String(m).padStart(2, "0")}m` : `${m}m ${String(s).padStart(2, "0")}s`;
    };
    const timer = setInterval(tick, 1000);
    onPageCleanup(() => clearInterval(timer));
    tick();
  });
};

// --- Exit offer ------------------------------------------------------------
const EXIT_KEY = "cj:exit-offer-seen";

const startExitOffer = (root = document) => {
  const modal = root.querySelector("[data-exit-offer]");
  if (!modal) return;

  let seen = false;
  try { seen = localStorage.getItem(EXIT_KEY) === "1"; } catch { seen = false; }
  if (seen) return;

  let open = false;
  const remember = () => { try { localStorage.setItem(EXIT_KEY, "1"); } catch { /* private mode */ } };

  const show = () => {
    if (open) return;
    open = true;
    modal.hidden = false;
    requestAnimationFrame(() => modal.classList.add("is-open"));
    remember();
    document.removeEventListener("mouseout", onLeave);
  };

  const close = () => {
    modal.classList.remove("is-open");
    setTimeout(() => { modal.hidden = true; }, 250);
  };

  // Desktop: the pointer leaving through the top of the window. Touch devices have
  // no such signal, so there the trigger is time on page plus real scrolling.
  const onLeave = (event) => {
    if (event.clientY > 4 || event.relatedTarget || event.buttons) return;
    show();
  };

  if (window.matchMedia("(hover: hover)").matches) {
    document.addEventListener("mouseout", onLeave, { signal: pageEvents.signal });
  } else {
    let scrolled = false;
    addEventListener("scroll", () => { scrolled = window.scrollY > 600; }, { passive: true, signal: pageEvents.signal });
    const timer = setTimeout(() => { if (scrolled) show(); }, 25000);
    onPageCleanup(() => clearTimeout(timer));
  }

  modal.querySelectorAll("[data-exit-close]").forEach((el) => el.addEventListener("click", close, { signal: pageEvents.signal }));
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && open) close(); }, { signal: pageEvents.signal });
  onPageCleanup(() => { modal.hidden = true; modal.classList.remove("is-open"); });
};

// --- Scroll reveals --------------------------------------------------------
// Anything marked .reveal fades up the first time it enters the viewport. The
// class is only added when the browser can observe it and the reader has not
// asked for less motion — otherwise the content is left visible.
const startReveals = (root = document) => {
  const targets = root.querySelectorAll(".reveal:not([data-revealed])");
  if (!targets.length) return;

  const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (still || !("IntersectionObserver" in window)) {
    targets.forEach((el) => { el.setAttribute("data-revealed", ""); el.classList.add("is-in"); });
    return;
  }

  const reveal = (el) => {
    el.setAttribute("data-revealed", "");
    el.classList.add("is-in");
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      reveal(entry.target);
      observer.unobserve(entry.target);
    });
  }, { rootMargin: "0px 0px 40px 0px", threshold: 0 });

  targets.forEach((el) => {
    // Already on screen: show it now rather than waiting for a scroll that may
    // never come on a short page.
    if (el.getBoundingClientRect().top < window.innerHeight) return reveal(el);
    el.classList.add("is-reveal-pending");
    observer.observe(el);
  });
  const preference = window.matchMedia("(prefers-reduced-motion: reduce)");
  preference.addEventListener("change", () => {
    if (!preference.matches) return;
    observer.disconnect();
    targets.forEach(reveal);
  }, { signal: pageEvents.signal });
  onPageCleanup(() => { observer.disconnect(); targets.forEach(reveal); });
};

// No offscreen animation work; the ticker also stops in a background tab.
const startTicker = () => {
  const ticker = document.querySelector(".ticker");
  if (!ticker || !("IntersectionObserver" in window)) return;
  let visible = true;
  const update = () => ticker.style.setProperty("--ticker-play-state", visible && !document.hidden ? "running" : "paused");
  const observer = new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; update(); });
  observer.observe(ticker);
  document.addEventListener("visibilitychange", update, { signal: pageEvents.signal });
  onPageCleanup(() => observer.disconnect());
};

// Reviews use native touch scrolling and CSS scroll snap. On a phone, start on
// the middle review so both neighbours are visible and the swipe is discoverable.
const startReviewCarousels = (root = document) => {
  const mobile = window.matchMedia("(max-width: 759px)");

  root.querySelectorAll("[data-review-carousel]").forEach((carousel) => {
    if (carousel.dataset.carouselReady) return;
    carousel.dataset.carouselReady = "1";

    const centerMiddleReview = () => {
      if (!mobile.matches) return;
      const cards = carousel.querySelectorAll(".testimonial");
      const middle = cards[Math.floor(cards.length / 2)];
      if (!middle) return;

      const railBox = carousel.getBoundingClientRect();
      const cardBox = middle.getBoundingClientRect();
      carousel.scrollLeft += cardBox.left - railBox.left - (railBox.width - cardBox.width) / 2;
    };

    const frame = requestAnimationFrame(centerMiddleReview);
    mobile.addEventListener?.("change", centerMiddleReview, { signal: pageEvents.signal });
    carousel.addEventListener("keydown", (event) => {
      if (!mobile.matches || !["ArrowLeft", "ArrowRight"].includes(event.key)) return;
      event.preventDefault();
      const distance = carousel.querySelector(".testimonial")?.getBoundingClientRect().width || carousel.clientWidth;
      carousel.scrollBy({ left: (distance + 12) * (event.key === "ArrowRight" ? 1 : -1),
        behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    }, { signal: pageEvents.signal });
    onPageCleanup(() => { cancelAnimationFrame(frame); delete carousel.dataset.carouselReady; });
  });
};

// --- Support assistant -----------------------------------------------------
// The panel only collects the message and renders the answer. Order status is
// resolved server-side from the session, so nothing here can be talked into
// revealing another customer's order.
const startSupportChat = (root = document) => {
  const chat = root.querySelector("[data-chat]");
  if (!chat || chat.dataset.ready) return;
  chat.dataset.ready = "1";

  const panel = chat.querySelector("[data-chat-panel]");
  const log = chat.querySelector("[data-chat-log]");
  const form = chat.querySelector("[data-chat-form]");
  const input = chat.querySelector("[data-chat-input]");
  const send = chat.querySelector("[data-chat-send]");
  const toggles = chat.querySelectorAll("[data-chat-toggle]");
  const launcher = chat.querySelector("[data-chat-toggle]");
  // Only the last few turns are sent: the server caps it anyway, and a long
  // transcript costs tokens without improving the answer.
  const history = [];
  let busy = false;

  const open = () => {
    panel.hidden = false;
    requestAnimationFrame(() => chat.classList.add("is-open"));
    toggles.forEach((t) => t.setAttribute("aria-expanded", "true"));
    setTimeout(() => input.focus(), 120);
  };

  const close = () => {
    chat.classList.remove("is-open");
    toggles.forEach((t) => t.setAttribute("aria-expanded", "false"));
    setTimeout(() => { panel.hidden = true; }, 200);
    launcher?.focus();
  };

  const toggle = () => (chat.classList.contains("is-open") ? close() : open());

  const bubble = (text, kind) => {
    const el = document.createElement("div");
    el.className = `chat__msg chat__msg--${kind}`;
    // textContent, never innerHTML: a reply is untrusted text.
    const p = document.createElement("p");
    p.textContent = text;
    el.appendChild(p);
    log.appendChild(el);
    log.scrollTop = log.scrollHeight;
    return el;
  };

  const typing = () => {
    const el = document.createElement("div");
    el.className = "chat__typing";
    el.innerHTML = "<span></span><span></span><span></span>";
    log.appendChild(el);
    log.scrollTop = log.scrollHeight;
    return el;
  };

  const ask = async (text) => {
    if (busy || !text.trim()) return;
    busy = true;
    send.disabled = true;
    chat.querySelector("[data-chat-chips]")?.remove();
    bubble(text, "me");
    input.value = "";
    const dots = typing();

    try {
      const token = document.querySelector("meta[name=csrf-token]")?.content;
      const response = await fetch("/support/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token || "" },
        body: JSON.stringify({ message: text, history })
      });
      const data = await response.json();
      dots.remove();

      if (!response.ok && response.status !== 429) throw new Error("bad status");
      bubble(data.reply, response.status === 429 ? "error" : "bot");

      history.push({ role: "user", content: text }, { role: "assistant", content: data.reply });
      if (history.length > 6) history.splice(0, history.length - 6);
    } catch {
      dots.remove();
      bubble("I could not reach the assistant. Try again in a moment, or email us and a human will answer.", "error");
    } finally {
      busy = false;
      send.disabled = false;
      input.focus();
    }
  };

  toggles.forEach((t) => t.addEventListener("click", toggle, { signal: pageEvents.signal }));
  form.addEventListener("submit", (e) => { e.preventDefault(); ask(input.value); }, { signal: pageEvents.signal });
  chat.querySelectorAll("[data-chat-suggest]").forEach((chip) =>
    chip.addEventListener("click", () => ask(chip.textContent.trim()), { signal: pageEvents.signal }));
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && chat.classList.contains("is-open")) close();
  }, { signal: pageEvents.signal });
  onPageCleanup(() => {
    delete chat.dataset.ready;
    chat.classList.remove("is-open");
    panel.hidden = true;
    toggles.forEach((t) => t.setAttribute("aria-expanded", "false"));
  });
};

const stopStorefront = () => {
  pageEvents?.abort();
  pageCleanups.splice(0).forEach((cleanup) => cleanup());
  activeBody = null;
};

const startStorefront = () => {
  // DOMContentLoaded and turbo:load both fire on the first visit.
  if (activeBody === document.body) return;
  stopStorefront();
  activeBody = document.body;
  pageEvents = new AbortController();
  startScrollProgress();
  rollOdometers();
  startReveals();
  startTicker();
  startReviewCarousels();
  startSupportChat();
  startCutoffClocks();
  startExitOffer();
};

document.addEventListener("DOMContentLoaded", startStorefront);
document.addEventListener("turbo:load", startStorefront);
document.addEventListener("turbo:before-cache", stopStorefront);
document.addEventListener("turbo:before-render", stopStorefront);
