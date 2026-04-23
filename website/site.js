document.addEventListener("DOMContentLoaded", () => {
  const revealTargets = document.querySelectorAll("[data-reveal]");
  document.documentElement.classList.add("js-enhanced");

  revealTargets.forEach((target, index) => {
    window.setTimeout(() => {
      target.classList.add("is-visible");
    }, Math.min(index * 70, 280));
  });
});
