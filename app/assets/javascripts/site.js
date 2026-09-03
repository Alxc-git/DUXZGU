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
