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
// Entries are real paid orders serialised by the server; this only cycles them.
const relativeTime = (iso) => {
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (minutes < 60) return `${Math.max(1, minutes)} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  const days = Math.round(hours / 24);
  return days === 1 ? "yesterday" : `${days} days ago`;
};

const startProofToasts = (root = document) => {
  const toast = root.querySelector("[data-proof]");
  const data = root.querySelector("[data-proof-data]");
  if (!toast || !data) return;

  let entries = [];
  try { entries = JSON.parse(data.textContent) || []; } catch { return; }
  if (!entries.length) return;

  const who = toast.querySelector("[data-proof-who]");
  const when = toast.querySelector("[data-proof-when]");
  let index = 0;
  let hideTimer;

  const show = () => {
    const entry = entries[index % entries.length];
    index += 1;
    const jars = entry.quantity > 1 ? `${entry.quantity} jars` : "a jar";
    who.textContent = `${entry.who} in ${entry.where} ordered ${jars}`;
    when.textContent = relativeTime(entry.at);
    toast.hidden = false;
    requestAnimationFrame(() => toast.classList.add("is-in"));
    hideTimer = setTimeout(hide, 6000);
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
  const loop = setInterval(show, 14000);
  setTimeout(show, 6000);
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

const startStorefront = () => {
  rollOdometers();
  startCutoffClocks();
  startProofToasts();
  startExitOffer();
};

document.addEventListener("DOMContentLoaded", startStorefront);
document.addEventListener("turbo:load", startStorefront);
