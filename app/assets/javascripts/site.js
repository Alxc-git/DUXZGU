// Progressive enhancement only — every screen works without it.
document.addEventListener("click", (event) => {
  // Mobile nav sheet
  const toggle = event.target.closest("[data-nav-toggle]");
  if (toggle) {
    const sheet = toggle.closest("[data-nav]").querySelector("[data-nav-sheet]");
    sheet.classList.toggle("is-open");
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

document.addEventListener("DOMContentLoaded", () => rollOdometers());
document.addEventListener("turbo:load", () => rollOdometers());
