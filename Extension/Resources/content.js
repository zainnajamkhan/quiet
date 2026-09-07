//
//  content.js
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

(function () {
  "use strict";

  const STYLE_ELEMENT_ID = "quiet-hidden-elements";
  const api = typeof browser !== "undefined" ? browser : chrome;

  let currentHref = null;
  let state = null;

  function styleElement() {
    const existing = document.getElementById(STYLE_ELEMENT_ID);
    if (existing) return existing;

    const element = document.createElement("style");
    element.id = STYLE_ELEMENT_ID;
    element.setAttribute("type", "text/css");
    const parent = document.head || document.documentElement;
    if (!parent) return null;
    parent.appendChild(element);
    return element;
  }

  function applyStylesheet(css) {
    const element = styleElement();
    if (!element) return;
    if (element.textContent !== css) {
      element.textContent = css;
    }
  }

  const BLOCK_ELEMENT_ID = "quiet-blocked-overlay";

  function showBlockOverlay() {
    if (document.getElementById(BLOCK_ELEMENT_ID)) return;
    const parent = document.body || document.documentElement;
    if (!parent) return;

    const overlay = document.createElement("div");
    overlay.id = BLOCK_ELEMENT_ID;
    overlay.setAttribute(
      "style",
      [
        "position:fixed", "inset:0", "z-index:2147483647",
        "background:#111", "color:#eee",
        "display:flex", "flex-direction:column",
        "align-items:center", "justify-content:center",
        "font:16px/1.5 -apple-system,system-ui,sans-serif",
        "text-align:center", "padding:2rem",
      ].join(";")
    );

    const heading = document.createElement("div");
    heading.textContent = "Blocked by Quiet";
    heading.setAttribute("style", "font-size:22px;font-weight:600;margin-bottom:8px");

    const detail = document.createElement("div");
    detail.textContent = window.location.hostname + " is on your blocked list.";
    detail.setAttribute("style", "opacity:0.75");

    overlay.appendChild(heading);
    overlay.appendChild(detail);
    parent.appendChild(overlay);

    // Stopping media matters as much as covering the page: audio continuing behind an
    // overlay would make the block feel broken.
    document.querySelectorAll("video, audio").forEach(function (el) {
      try { el.pause(); } catch (_) {}
    });
  }

  function removeBlockOverlay() {
    const existing = document.getElementById(BLOCK_ELEMENT_ID);
    if (existing && existing.parentNode) existing.parentNode.removeChild(existing);
  }

  function evaluate() {
    if (!state || !state.ruleset) {
      applyStylesheet("");
      removeBlockOverlay();
      return;
    }

    if (QuietRules.isHostBlocked(window.location.hostname, state.blockedHosts)) {
      applyStylesheet("");
      showBlockOverlay();
      return;
    }
    removeBlockOverlay();

    const href = window.location.href;
    const site = QuietRules.siteForURL(state.ruleset, href);
    if (!site) {
      applyStylesheet("");
      return;
    }
    const features = QuietRules.activeFeatures(site, href, state.preferences);
    applyStylesheet(QuietRules.buildStylesheet(features));
  }

  function refreshIfNavigated() {
    if (window.location.href === currentHref) return;
    currentHref = window.location.href;
    evaluate();
  }

  async function loadState() {
    try {
      const response = await api.runtime.sendMessage({ type: "quiet.state" });
      if (response && response.ruleset) {
        state = response;
        evaluate();
      }
    } catch (_) {
      applyStylesheet("");
    }
  }

  api.runtime.onMessage.addListener((message) => {
    if (message && message.type === "quiet.stateChanged") {
      state = message.state;
      evaluate();
    }
  });

  // Single page sites change the URL without a document load, so the applicable feature
  // set has to be recomputed as the DOM settles rather than only once at startup.
  const observer = new MutationObserver(refreshIfNavigated);
  observer.observe(document.documentElement, { childList: true, subtree: true });
  window.addEventListener("popstate", refreshIfNavigated);
  window.addEventListener("pageshow", refreshIfNavigated);

  currentHref = window.location.href;
  loadState();
})();
