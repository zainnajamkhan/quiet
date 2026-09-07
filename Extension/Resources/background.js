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
const STORAGE_KEY_RULESET_SYNCED_AT = "quiet.rulesetSyncedAt";

// The extension does not fetch rules itself. It has no network permission, and the code
// that decides whether a published ruleset is safe to run lives in the app, where it is
// unit tested; a second copy here would be a second thing to get wrong. The app downloads
// and validates, and this only collects the result.
const RULESET_SYNC_INTERVAL_MS = 6 * 60 * 60 * 1000;

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

// The applicationID argument is required by the WebExtension API shape but ignored by
// Safari, which only ever has one possible native host: this extension's own containing
// app. A failure here (no app installed yet, message handler not reachable) must never
// break hiding, so it degrades to "no native overrides" rather than throwing.
async function readSharedStateFromNativeApp() {
  try {
    const response = await api.runtime.sendNativeMessage("quiet", { type: "quiet.getSharedState" });
    return {
      preferences: (response && response.preferences) || {},
      blockedHosts: (response && response.blockedHosts) || [],
    };
  } catch (_) {
    return { preferences: {}, blockedHosts: [] };
  }
}

async function writeStored(key, value) {
  try {
    await api.storage.local.set({ [key]: value });
  } catch (_) {
    // A full or unavailable store only costs a re-fetch next time.
  }
}

// Copies whatever ruleset the app has accepted into extension storage, so the hot path in
// buildState keeps reading one cheap local value rather than paying for a native round trip
// on every page load. Any failure leaves the previous copy in place.
async function syncRemoteRuleset() {
  try {
    const response = await api.runtime.sendNativeMessage("quiet", {
      type: "quiet.getRemoteRuleset",
    });
    const ruleset = response && response.ruleset ? response.ruleset : null;
    await writeStored(STORAGE_KEY_REMOTE_RULESET, ruleset);
    await writeStored(STORAGE_KEY_RULESET_SYNCED_AT, Date.now());
  } catch (_) {
    // No app installed, or it has never accepted an update. Bundled rules still apply.
  }
}

async function syncRemoteRulesetIfStale() {
  const syncedAt = await readStored(STORAGE_KEY_RULESET_SYNCED_AT);
  if (typeof syncedAt === "number" && Date.now() - syncedAt < RULESET_SYNC_INTERVAL_MS) return;
  await syncRemoteRuleset();
}

async function buildState() {
  const bundled = await readBundledRuleset();
  const remote = await readStored(STORAGE_KEY_REMOTE_RULESET);
  const localPreferences = (await readStored(STORAGE_KEY_PREFERENCES)) || {};
  const native = await readSharedStateFromNativeApp();
  const nativePreferences = native.preferences;

  // Native app overrides win over what the extension stored locally, so the container
  // app's settings UI (once it exists) is the source of truth; anything it hasn't
  // expressed an opinion on falls back to local storage, then to each feature's own
  // defaultEnabled inside the ruleset engine itself.
  const preferences = { ...localPreferences, ...nativePreferences };

  const chosen = QuietRules.chooseRuleset(bundled, remote);
  return {
    ruleset: chosen.ruleset,
    preferences,
    blockedHosts: native.blockedHosts,
    source: chosen.source,
    reason: chosen.reason,
  };
}

// Deliberately not cached: the native app can change shared state at any time with no
// event the extension can listen for, so every request rebuilds from scratch rather than
// risking a stale answer. Revisit if this ever shows up as a real performance cost.
async function currentState() {
  return buildState();
}

async function broadcastState() {
  const state = await currentState();
  const tabs = await api.tabs.query({});
  for (const tab of tabs) {
    if (typeof tab.id !== "number") continue;
    api.tabs.sendMessage(tab.id, { type: "quiet.stateChanged", state }).catch(() => {});
  }
}

api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || message.type !== "quiet.state") return false;
  // Deliberately not awaited: a page must never wait on a rule sync to find out what to
  // hide. A newly synced ruleset takes effect on the next navigation.
  syncRemoteRulesetIfStale().then(broadcastState);
  currentState().then(sendResponse);
  return true;
});

api.storage.onChanged.addListener((changes, areaName) => {
  if (areaName !== "local") return;
  if (STORAGE_KEY_REMOTE_RULESET in changes || STORAGE_KEY_PREFERENCES in changes) {
    broadcastState();
  }
});

// Safari can tear a background page down and bring it back, so this runs on every load
// rather than only on install.
syncRemoteRulesetIfStale();
