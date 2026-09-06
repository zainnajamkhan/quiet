//
//  background.js
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import "./rules-engine.js";

const api = typeof browser !== "undefined" ? browser : chrome;

const BUNDLED_RULESET_PATH = "ruleset.json";
const STORAGE_KEY_REMOTE_RULESET = "quiet.remoteRuleset";
const STORAGE_KEY_PREFERENCES = "quiet.preferences";

let cachedState = null;

async function readBundledRuleset() {
  const response = await fetch(api.runtime.getURL(BUNDLED_RULESET_PATH));
  return response.json();
}

async function readStored(key) {
  try {
    const stored = await api.storage.local.get(key);
    return stored ? stored[key] : null;
  } catch (_) {
    return null;
  }
}

async function buildState() {
  const bundled = await readBundledRuleset();
  const remote = await readStored(STORAGE_KEY_REMOTE_RULESET);
  const preferences = (await readStored(STORAGE_KEY_PREFERENCES)) || {};

  const chosen = QuietRules.chooseRuleset(bundled, remote);
  return { ruleset: chosen.ruleset, preferences, source: chosen.source, reason: chosen.reason };
}

async function currentState() {
  if (!cachedState) {
    cachedState = await buildState();
  }
  return cachedState;
}

async function broadcastState() {
  cachedState = await buildState();
  const tabs = await api.tabs.query({});
  for (const tab of tabs) {
    if (typeof tab.id !== "number") continue;
    api.tabs.sendMessage(tab.id, { type: "quiet.stateChanged", state: cachedState }).catch(() => {});
  }
}

api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || message.type !== "quiet.state") return false;
  currentState().then(sendResponse);
  return true;
});

api.storage.onChanged.addListener((changes, areaName) => {
  if (areaName !== "local") return;
  if (STORAGE_KEY_REMOTE_RULESET in changes || STORAGE_KEY_PREFERENCES in changes) {
    broadcastState();
  }
});
