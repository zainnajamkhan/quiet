#!/usr/bin/env node
"use strict";

// Generates Tools/selector-check.js: a self contained snippet to paste into Safari's Web
// Inspector console on a live page. It reports, per feature, whether each selector still
// matches anything, which is the only way to tell a working rule from one that silently
// broke when the site reshipped its DOM.
//
// Regenerate after every ruleset change:  node Tools/make-selector-check.js

const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const ruleset = JSON.parse(
  fs.readFileSync(path.join(root, "Extension", "Resources", "ruleset.json"), "utf8")
);

const snippet = `// Quiet selector check, generated from ruleset v${ruleset.rulesetVersion}.
// Paste into Safari's Web Inspector console (Develop > Show Web Inspector > Console)
// while on the site you want to check, then read the table.
(function () {
  var RULESET = ${JSON.stringify(ruleset, null, 2)};

  function globToRegExp(glob) {
    return new RegExp("^" + String(glob).replace(/[.+?^\${}()|[\\]\\\\]/g, "\\\\$&").replace(/\\*/g, ".*") + "$");
  }

  function hostMatches(patternHost, host) {
    if (patternHost === "*") return true;
    if (patternHost.indexOf("*.") === 0) {
      var suffix = patternHost.slice(2);
      return host === suffix || host.slice(-(suffix.length + 1)) === "." + suffix;
    }
    return host === patternHost;
  }

  function siteForHost(host) {
    for (var i = 0; i < RULESET.sites.length; i++) {
      var site = RULESET.sites[i];
      for (var j = 0; j < site.matches.length; j++) {
        var m = /^(\\*|https?):\\/\\/([^/]+)(\\/.*)$/.exec(site.matches[j]);
        if (m && hostMatches(m[2].toLowerCase(), host)) return site;
      }
    }
    return null;
  }

  function count(selector) {
    try {
      return document.querySelectorAll(selector).length;
    } catch (e) {
      return "INVALID SELECTOR";
    }
  }

  var host = location.hostname.toLowerCase();
  var site = siteForHost(host);
  if (!site) {
    console.log("%cQuiet: no rules defined for " + host, "color:orange;font-weight:bold");
    return;
  }

  var pathAndQuery = location.pathname + location.search;
  console.log("%cQuiet selector check -- " + site.name + " -- " + pathAndQuery, "font-weight:bold;font-size:14px");

  var rows = [];
  site.features.forEach(function (feature) {
    var applies = true;
    if (feature.appliesTo && feature.appliesTo.length) {
      applies = feature.appliesTo.some(function (g) { return globToRegExp(g).test(pathAndQuery); });
    }

    var pageRecognised = true;
    if (feature.verify && feature.verify.length) {
      pageRecognised = feature.verify.some(function (s) { return count(s) > 0; });
    }

    feature.hide.forEach(function (selector) {
      var n = count(selector);
      var status;
      if (!applies) status = "n/a on this page";
      else if (!pageRecognised) status = "PAGE NOT RECOGNISED (verify selector missing)";
      else if (n === "INVALID SELECTOR") status = "INVALID SELECTOR";
      else if (n === 0) status = "*** BROKEN: matches nothing ***";
      else status = "ok (" + n + ")";

      rows.push({ feature: feature.id, selector: selector, matches: n, status: status });
    });
  });

  if (console.table) console.table(rows);
  else rows.forEach(function (r) { console.log(r.feature, r.selector, r.status); });

  var broken = rows.filter(function (r) { return r.status.indexOf("BROKEN") >= 0 || r.status.indexOf("INVALID") >= 0; });
  if (broken.length === 0) {
    console.log("%cAll applicable selectors matched something.", "color:green;font-weight:bold");
  } else {
    console.log("%c" + broken.length + " selector(s) need fixing:", "color:red;font-weight:bold");
    broken.forEach(function (r) { console.log("  " + r.feature + "  ->  " + r.selector); });
  }
})();
`;

const outPath = path.join(root, "Tools", "selector-check.js");
fs.writeFileSync(outPath, snippet);
console.log("Wrote " + path.relative(root, outPath));
console.log("Ruleset v" + ruleset.rulesetVersion + ": " + ruleset.sites.length + " sites, " +
  ruleset.sites.reduce(function (t, s) { return t + s.features.length; }, 0) + " features");
