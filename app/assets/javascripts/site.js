// Progressive enhancement only — every screen works without it.
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
      .forEach((el) => el.classList.remove("is-open"));
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

  if (!("IntersectionObserver" in window)) {
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
};


// --- Dispatch countdown ----------------------------------------------------
// The cutoff instant is rendered by the server; this only ticks the label down.
const startCutoffClocks = (root = document) => {
  root.querySelectorAll("[data-cutoff]").forEach((el) => {
    const clock = el.querySelector("[data-cutoff-clock]");
    if (!clock) return;

    const target = new Date(el.getAttribute("data-cutoff")).getTime();
    const tick = () => {
      const left = Math.max(0, Math.floor((target - Date.now()) / 1000));
      if (left === 0) { clearInterval(timer); el.hidden = true; return; }
      const h = Math.floor(left / 3600);
      const m = Math.floor((left % 3600) / 60);
      const s = left % 60;
      clock.textContent = h > 0 ? `${h}h ${String(m).padStart(2, "0")}m` : `${m}m ${String(s).padStart(2, "0")}s`;
    };
    const timer = setInterval(tick, 1000);
    tick();
  });
};

// --- Social proof ----------------------------------------------------------
// Entries are real paid orders serialised by the server; this only phrases and
// cycles them. With too few recent orders the server sends an aggregate instead.
const relativeTime = (iso) => {
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (minutes < 2) return "just now";
  if (minutes < 60) return `${minutes} minutes ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return hours === 1 ? "an hour ago" : `${hours} hours ago`;
  const days = Math.round(hours / 24);
  return days === 1 ? "yesterday" : `${days} days ago`;
};

const startProofToasts = (root = document) => {
  const toast = root.querySelector("[data-proof]");
  const data = root.querySelector("[data-proof-data]");
  if (!toast || !data) return;

  let payload = {};
  try { payload = JSON.parse(data.textContent) || {}; } catch { return; }

  const entries = Array.isArray(payload.entries) ? payload.entries : [];
  const summary = payload.summary;
  if (!entries.length && !summary) return;

  const who = toast.querySelector("[data-proof-who]");
  const when = toast.querySelector("[data-proof-when]");
  let index = 0;
  let hideTimer;

  const render = () => {
    if (!entries.length) {
      who.textContent = `${summary.count} people ordered in the last ${summary.days} days`;
      when.textContent = "Verified orders";
      return;
    }
    const entry = entries[index % entries.length];
    index += 1;
    const jars = entry.quantity > 1 ? `${entry.quantity} jars` : "a jar";
    who.textContent = `${entry.who} in ${entry.city} ordered ${jars}`;
    when.textContent = relativeTime(entry.at);
  };

  const show = () => {
    render();
    toast.hidden = false;
    requestAnimationFrame(() => toast.classList.add("is-in"));
    hideTimer = setTimeout(hide, 6500);
  };

  const hide = () => {
    toast.classList.remove("is-in");
    setTimeout(() => { toast.hidden = true; }, 400);
  };

  const stop = () => {
    clearTimeout(hideTimer);
    clearInterval(loop);
    hide();
  };

  toast.querySelector("[data-proof-close]")?.addEventListener("click", stop);
  // A single aggregate has nothing to cycle through: show it once and stop.
  const loop = entries.length > 1 ? setInterval(show, 15000) : null;
  setTimeout(show, 7000);
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
    document.addEventListener("mouseout", onLeave);
  } else {
    let scrolled = false;
    addEventListener("scroll", () => { scrolled = window.scrollY > 600; }, { passive: true });
    setTimeout(() => { if (scrolled) show(); }, 25000);
  }

  modal.querySelectorAll("[data-exit-close]").forEach((el) => el.addEventListener("click", close));
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && open) close(); });
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
  }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });

  targets.forEach((el) => {
    // Already on screen: show it now rather than waiting for a scroll that may
    // never come on a short page.
    if (el.getBoundingClientRect().top < window.innerHeight) return reveal(el);
    observer.observe(el);
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

  toggles.forEach((t) => t.addEventListener("click", toggle));
  form.addEventListener("submit", (e) => { e.preventDefault(); ask(input.value); });
  chat.querySelectorAll("[data-chat-suggest]").forEach((chip) =>
    chip.addEventListener("click", () => ask(chip.textContent.trim())));
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && chat.classList.contains("is-open")) close();
  });
};

const startStorefront = () => {
  rollOdometers();
  startReveals();
  startSupportChat();
  startCutoffClocks();
  startProofToasts();
  startExitOffer();
};

document.addEventListener("DOMContentLoaded", startStorefront);
document.addEventListener("turbo:load", startStorefront);
