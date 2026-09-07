//
//  rules-engine.js
//  Quiet
//
//  Created by Zain Najam Khan.
//  Copyright © 2026 Zain Najam Khan. All rights reserved.
//

// Pure ruleset logic: no DOM, no browser APIs, no I/O. The same file is loaded by the
// content script and required by the Node tests, so what ships is what is tested.

(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module && module.exports) {
    module.exports = api;
  } else {
    root.QuietRules = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const SUPPORTED_SCHEMA_VERSION = 1;

  const SITE_ID = /^[a-z0-9]+(-[a-z0-9]+)*$/;
  const FEATURE_ID = /^[a-z0-9]+(-[a-z0-9]+)*\.[a-z0-9]+(-[a-z0-9]+)*$/;
  const MATCH_PATTERN = /^(\*|https?):\/\/(\*|(?:\*\.)?[A-Za-z0-9.-]+)(\/.*)$/;

  // A selector is injected into a stylesheet as `<selector> { display: none !important; }`
  // and its feature id into a `/* ... */` comment. These characters would let a malformed
  // or hostile ruleset escape that context, and none of them are legal in a CSS selector.
  // `>`, `~`, `+`, `*`, `[`, `]`, `(`, `)` and `:` are all legal and stay allowed.
  const UNSAFE_IN_SELECTOR = /[{};<]|\*\//;

  function isSafeSelector(value) {
    return typeof value === "string" && value.length > 0 && !UNSAFE_IN_SELECTOR.test(value);
  }

  function globToRegExp(glob) {
    const escaped = String(glob)
      .replace(/[.+?^${}()|[\]\\]/g, "\\$&")
      .replace(/\*/g, ".*");
    return new RegExp("^" + escaped + "$");
  }

  function parseMatchPattern(pattern) {
    if (typeof pattern !== "string") return null;
    const parts = MATCH_PATTERN.exec(pattern);
    if (!parts) return null;
    return { scheme: parts[1], host: parts[2].toLowerCase(), path: parts[3] };
  }

  function parseURL(url) {
    try {
      return new URL(url);
    } catch (_) {
      return null;
    }
  }

  function hostMatches(patternHost, host) {
    if (patternHost === "*") return true;
    if (patternHost.startsWith("*.")) {
      const suffix = patternHost.slice(2);
      return host === suffix || host.endsWith("." + suffix);
    }
    return host === patternHost;
  }

  function schemeMatches(patternScheme, protocol) {
    const scheme = protocol.replace(/:$/, "").toLowerCase();
    if (patternScheme === "*") return scheme === "http" || scheme === "https";
    return scheme === patternScheme;
  }

  // The part of a URL that path globs and `appliesTo` are matched against.
  function pathOf(parsed) {
    return parsed.pathname + parsed.search;
  }

  function matchesPattern(pattern, url) {
    const parsedPattern = parseMatchPattern(pattern);
    if (!parsedPattern) return false;
    const parsed = parseURL(url);
    if (!parsed) return false;
    if (!schemeMatches(parsedPattern.scheme, parsed.protocol)) return false;
    if (!hostMatches(parsedPattern.host, parsed.hostname.toLowerCase())) return false;
    return globToRegExp(parsedPattern.path).test(pathOf(parsed));
  }

  function validateRuleset(ruleset) {
    const errors = [];
    const push = (message) => errors.push(message);

    if (!ruleset || typeof ruleset !== "object" || Array.isArray(ruleset)) {
      return { ok: false, errors: ["ruleset is not an object"] };
    }
    if (!Number.isInteger(ruleset.schemaVersion)) push("schemaVersion is not an integer");
    if (!Number.isInteger(ruleset.rulesetVersion) || ruleset.rulesetVersion < 1) {
      push("rulesetVersion is not a positive integer");
    }
    if (!Array.isArray(ruleset.sites) || ruleset.sites.length === 0) {
      push("sites is not a non empty array");
      return { ok: errors.length === 0, errors };
    }

    const seenSiteIds = new Set();
    const seenFeatureIds = new Set();

    ruleset.sites.forEach((site, siteIndex) => {
      const where = "sites[" + siteIndex + "]";
      if (!site || typeof site !== "object") {
        push(where + " is not an object");
        return;
      }
      if (!SITE_ID.test(site.id || "")) push(where + ".id is missing or malformed");
      if (seenSiteIds.has(site.id)) push(where + ".id is a duplicate: " + site.id);
      seenSiteIds.add(site.id);
      if (typeof site.name !== "string" || site.name.length === 0) push(where + ".name is missing");

      if (!Array.isArray(site.matches) || site.matches.length === 0) {
        push(where + ".matches is not a non empty array");
      } else {
        site.matches.forEach((pattern, i) => {
          if (!parseMatchPattern(pattern)) {
            push(where + ".matches[" + i + "] is not a valid match pattern: " + pattern);
          }
        });
      }

      if (!Array.isArray(site.features) || site.features.length === 0) {
        push(where + ".features is not a non empty array");
        return;
      }

      site.features.forEach((feature, featureIndex) => {
        const at = where + ".features[" + featureIndex + "]";
        if (!feature || typeof feature !== "object") {
          push(at + " is not an object");
          return;
        }
        if (!FEATURE_ID.test(feature.id || "")) {
          push(at + ".id is missing or malformed");
        } else if (!feature.id.startsWith(site.id + ".")) {
          push(at + ".id must be namespaced under its site: " + feature.id);
        }
        if (seenFeatureIds.has(feature.id)) push(at + ".id is a duplicate: " + feature.id);
        seenFeatureIds.add(feature.id);

        if (typeof feature.name !== "string" || feature.name.length === 0) push(at + ".name is missing");
        if (typeof feature.defaultEnabled !== "boolean") push(at + ".defaultEnabled is not a boolean");

        if (!Array.isArray(feature.hide) || feature.hide.length === 0) {
          push(at + ".hide is not a non empty array");
        } else {
          feature.hide.forEach((selector, i) => {
            if (!isSafeSelector(selector)) push(at + ".hide[" + i + "] is unsafe or empty: " + selector);
          });
        }
        if (feature.verify !== undefined) {
          if (!Array.isArray(feature.verify)) {
            push(at + ".verify is not an array");
          } else {
            feature.verify.forEach((selector, i) => {
              if (!isSafeSelector(selector)) push(at + ".verify[" + i + "] is unsafe or empty: " + selector);
            });
          }
        }
        if (feature.appliesTo !== undefined) {
          if (!Array.isArray(feature.appliesTo) || feature.appliesTo.length === 0) {
            push(at + ".appliesTo is present but not a non empty array");
          } else {
            feature.appliesTo.forEach((glob, i) => {
              if (typeof glob !== "string" || glob.length === 0) {
                push(at + ".appliesTo[" + i + "] is not a non empty string");
              }
            });
          }
        }
      });
    });

    return { ok: errors.length === 0, errors };
  }

  function siteForURL(ruleset, url) {
    const check = validateRuleset(ruleset);
    if (!check.ok) return null;
    for (const site of ruleset.sites) {
      for (const pattern of site.matches) {
        if (matchesPattern(pattern, url)) return site;
      }
    }
    return null;
  }

  function isEnabled(feature, preferences) {
    if (preferences && Object.prototype.hasOwnProperty.call(preferences, feature.id)) {
      return preferences[feature.id] === true;
    }
    return feature.defaultEnabled === true;
  }

  function appliesToURL(feature, url) {
    if (!Array.isArray(feature.appliesTo) || feature.appliesTo.length === 0) return true;
    const parsed = parseURL(url);
    if (!parsed) return false;
    const path = pathOf(parsed);
    return feature.appliesTo.some((glob) => globToRegExp(glob).test(path));
  }

  // Features that should be applied to this URL right now, in ruleset order.
  // `preferences` maps feature id to a boolean and may be partial, null or undefined.
  function activeFeatures(site, url, preferences) {
    if (!site || !Array.isArray(site.features)) return [];
    return site.features.filter(
      (feature) => isEnabled(feature, preferences) && appliesToURL(feature, url)
    );
  }

  function buildStylesheet(features) {
    if (!Array.isArray(features)) return "";
    const blocks = [];
    for (const feature of features) {
      if (!feature || !Array.isArray(feature.hide)) continue;
      const selectors = feature.hide.filter(isSafeSelector);
      if (selectors.length === 0) continue;
      const label = isSafeSelector(feature.id) ? feature.id : "unnamed";
      blocks.push(
        "/* " + label + " */\n" + selectors.join(",\n") + " { display: none !important; }"
      );
    }
    return blocks.join("\n\n");
  }

  // Decide which of the bundled and the remotely fetched ruleset to use. The bundled copy
  // always wins unless the remote one is valid, understands the same schema, and is newer.
  // Mirrors HostPattern.matches in QuietCore: the domain itself and any subdomain, never a
  // lookalike such as notreddit.com for reddit.com.
  function isHostBlocked(host, blockedHosts) {
    if (typeof host !== "string" || !Array.isArray(blockedHosts)) return false;
    var normalised = host.trim().toLowerCase();
    if (normalised.endsWith(".")) normalised = normalised.slice(0, -1);
    if (!normalised) return false;
    return blockedHosts.some(function (blocked) {
      if (typeof blocked !== "string") return false;
      var domain = blocked.trim().toLowerCase();
      if (!domain) return false;
      return normalised === domain || normalised.endsWith("." + domain);
    });
  }

  function chooseRuleset(bundled, remote) {
    const bundledCheck = validateRuleset(bundled);
    if (!bundledCheck.ok) {
      return { ruleset: null, source: "none", reason: "bundled ruleset is invalid: " + bundledCheck.errors[0] };
    }
    if (bundled.schemaVersion !== SUPPORTED_SCHEMA_VERSION) {
      return { ruleset: null, source: "none", reason: "bundled ruleset schemaVersion is not supported" };
    }
    if (remote === null || remote === undefined) {
      return { ruleset: bundled, source: "bundled", reason: "no remote ruleset" };
    }
    const remoteCheck = validateRuleset(remote);
    if (!remoteCheck.ok) {
      return { ruleset: bundled, source: "bundled", reason: "remote ruleset is invalid: " + remoteCheck.errors[0] };
    }
    if (remote.schemaVersion !== SUPPORTED_SCHEMA_VERSION) {
      return { ruleset: bundled, source: "bundled", reason: "remote ruleset needs schema " + remote.schemaVersion };
    }
    if (remote.rulesetVersion <= bundled.rulesetVersion) {
      return { ruleset: bundled, source: "bundled", reason: "remote ruleset is not newer" };
    }
    return { ruleset: remote, source: "remote", reason: "remote ruleset version " + remote.rulesetVersion };
  }

  return {
    SUPPORTED_SCHEMA_VERSION,
    isSafeSelector,
    parseMatchPattern,
    matchesPattern,
    validateRuleset,
    isHostBlocked,
    siteForURL,
    activeFeatures,
    buildStylesheet,
    chooseRuleset,
  };
});
