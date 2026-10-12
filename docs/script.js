const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
const panels = Array.from(document.querySelectorAll("[data-code-panel]"));
const copyButton = document.querySelector("[data-copy]");

function activateTab(tab) {
  const selectedPanel = tab.dataset.panel;

  tabs.forEach((item) => {
    const isSelected = item === tab;
    item.setAttribute("aria-selected", String(isSelected));
    item.tabIndex = isSelected ? 0 : -1;
  });

  panels.forEach((panel) => {
    panel.hidden = panel.dataset.codePanel !== selectedPanel;
  });
}

tabs.forEach((tab, index) => {
  tab.addEventListener("click", () => activateTab(tab));

  tab.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;

    event.preventDefault();
    const direction = event.key === "ArrowRight" ? 1 : -1;
    const nextIndex = (index + direction + tabs.length) % tabs.length;
    tabs[nextIndex].focus();
    activateTab(tabs[nextIndex]);
  });
});

copyButton?.addEventListener("click", async () => {
  const activePanel = panels.find((panel) => !panel.hidden);
  const code = activePanel?.querySelector("code")?.textContent;

  if (!code) return;

  try {
    await navigator.clipboard.writeText(code);
    copyButton.textContent = "Copied";
  } catch {
    copyButton.textContent = "Copy failed";
  }

  window.setTimeout(() => {
    copyButton.textContent = "Copy";
  }, 1600);
});
