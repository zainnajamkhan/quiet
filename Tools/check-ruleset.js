#!/usr/bin/env node
"use strict";

// Validates every ruleset in the repository against the shipping engine. Exits non zero on
// the first invalid document, so this can gate a commit or a release.

const fs = require("node:fs");
const path = require("node:path");

const { validateRuleset } = require("../Extension/Resources/rules-engine.js");

const root = path.join(__dirname, "..");
const targets = [
  path.join(root, "Rules", "fixtures", "ruleset-fixture.json"),
  path.join(root, "Rules", "ruleset.json"),
  path.join(root, "Extension", "Resources", "ruleset.json"),
];

let failures = 0;
let checked = 0;

for (const target of targets) {
  if (!fs.existsSync(target)) continue;
  checked += 1;

  const relative = path.relative(root, target);
  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(target, "utf8"));
  } catch (error) {
    console.error("FAIL " + relative + ": not valid JSON: " + error.message);
    failures += 1;
    continue;
  }

  const result = validateRuleset(parsed);
  if (result.ok) {
    const featureCount = parsed.sites.reduce((total, site) => total + site.features.length, 0);
    console.log(
      "OK   " + relative + ": v" + parsed.rulesetVersion +
      ", " + parsed.sites.length + " sites, " + featureCount + " features"
    );
  } else {
    console.error("FAIL " + relative + ":");
    for (const error of result.errors) console.error("       " + error);
    failures += 1;
  }
}

if (checked === 0) {
  console.error("No rulesets found to check.");
  process.exit(1);
}
process.exit(failures === 0 ? 0 : 1);
