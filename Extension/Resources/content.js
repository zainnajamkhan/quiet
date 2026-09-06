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

  function evaluate() {
    if (!state || !state.ruleset) {
      applyStylesheet("");
      return;
    }
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
