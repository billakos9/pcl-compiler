const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
const panels = Array.from(document.querySelectorAll('[data-code-panel]'));
const copyButton = document.querySelector('[data-copy]');
const copyLabel = document.querySelector('[data-copy-label]');
const copyStatus = document.querySelector('[data-copy-status]');
let resetCopyTimeout;

function resetCopy() {
  window.clearTimeout(resetCopyTimeout);
  copyLabel.textContent = 'Copy';
  copyStatus.textContent = '';
}
function activateTab(tab) {
  resetCopy();
  tabs.forEach((item) => {
    const selected = item === tab;
    item.setAttribute('aria-selected', String(selected));
    item.tabIndex = selected ? 0 : -1;
  });
  panels.forEach((panel) => {
    panel.hidden = panel.dataset.codePanel !== tab.dataset.panel;
  });
  copyButton.setAttribute('aria-label', `Copy ${tab.textContent.trim()} code`);
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => activateTab(tab));
  tab.addEventListener('keydown', (event) => {
    let nextIndex;
    if (event.key === 'ArrowRight') nextIndex = (index + 1) % tabs.length;
    else if (event.key === 'ArrowLeft') nextIndex = (index - 1 + tabs.length) % tabs.length;
    else if (event.key === 'Home') nextIndex = 0;
    else if (event.key === 'End') nextIndex = tabs.length - 1;
    else return;
    event.preventDefault();
    tabs[nextIndex].focus();
    activateTab(tabs[nextIndex]);
  });
});
copyButton.addEventListener('click', async () => {
  const activePanel = panels.find((panel) => !panel.hidden);
  const code = activePanel?.querySelector('code')?.textContent;
  if (!code) return;
  resetCopy();
  try {
    await navigator.clipboard.writeText(code);
    if (activePanel.hidden) return;
    copyLabel.textContent = 'Copied';
    copyStatus.textContent = 'Code copied to clipboard.';
  } catch {
    if (activePanel.hidden) return;
    copyLabel.textContent = 'Select code';
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(activePanel.querySelector('code'));
    selection.removeAllRanges();
    selection.addRange(range);
    copyStatus.textContent = 'Automatic copy is unavailable. The code is selected; use your keyboard to copy.';
  }
  resetCopyTimeout = window.setTimeout(resetCopy, 2200);
});
