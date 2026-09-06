"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  SUPPORTED_SCHEMA_VERSION,
  isSafeSelector,
  parseMatchPattern,
  matchesPattern,
  validateRuleset,
  siteForURL,
  activeFeatures,
  buildStylesheet,
  chooseRuleset,
} = require("../Resources/rules-engine.js");

// The one fixture both engines are tested against. Rules/fixtures/ruleset-fixture.json is
// also loaded by the Swift tests in Packages/QuietCore, so the two implementations are
// proven to agree on the same document rather than on two copies that can drift apart.
const fs = require("node:fs");
const path = require("node:path");

const FIXTURE_PATH = path.join(__dirname, "..", "..", "Rules", "fixtures", "ruleset-fixture.json");
const FIXTURE = JSON.parse(fs.readFileSync(FIXTURE_PATH, "utf8"));

function fixture(overrides) {
  return Object.assign(structuredClone(FIXTURE), overrides || {});
}

test("parseMatchPattern accepts well formed patterns and rejects the rest", () => {
  assert.deepEqual(parseMatchPattern("*://*.example.com/*"), {
    scheme: "*",
    host: "*.example.com",
    path: "/*",
  });
  assert.deepEqual(parseMatchPattern("https://a.test/path/*"), {
    scheme: "https",
    host: "a.test",
    path: "/path/*",
  });
  assert.equal(parseMatchPattern("ftp://a.test/*"), null, "only http and https are allowed");
  assert.equal(parseMatchPattern("https://a.test"), null, "a path is required");
  assert.equal(parseMatchPattern("*.example.com/*"), null, "a scheme is required");
  assert.equal(parseMatchPattern(""), null);
  assert.equal(parseMatchPattern(null), null);
  assert.equal(parseMatchPattern(42), null);
});

test("matchesPattern handles schemes, hosts and paths", () => {
  assert.equal(matchesPattern("*://*.example.com/*", "https://www.example.com/"), true);
  assert.equal(matchesPattern("*://*.example.com/*", "http://example.com/watch?v=1"), true);
  assert.equal(matchesPattern("https://example.com/*", "http://example.com/"), false, "scheme must match");
  assert.equal(matchesPattern("*://*.example.com/*", "ftp://example.com/"), false, "wildcard scheme is http or https only");
  assert.equal(matchesPattern("*://*.example.com/*", "file:///Users/x/example.com"), false);
});

test("matchesPattern is not fooled by lookalike hosts", () => {
  // The classic subdomain wildcard bug: *.example.com must not match notexample.com.
  assert.equal(matchesPattern("*://*.example.com/*", "https://notexample.com/"), false);
  assert.equal(matchesPattern("*://*.example.com/*", "https://example.com.evil.test/"), false);
  assert.equal(matchesPattern("*://*.example.com/*", "https://example.com/"), true, "the bare domain matches too");
  assert.equal(matchesPattern("*://*.example.com/*", "https://deep.sub.example.com/"), true);
  assert.equal(matchesPattern("https://example.com/*", "https://sub.example.com/"), false, "an exact host is exact");
});

test("matchesPattern is case insensitive on the host only", () => {
  assert.equal(matchesPattern("*://*.example.com/*", "https://WWW.EXAMPLE.COM/Path"), true);
  assert.equal(matchesPattern("*://*.example.com/Path", "https://example.com/Path"), true);
  assert.equal(matchesPattern("*://*.example.com/Path", "https://example.com/path"), false, "paths stay case sensitive");
});

test("matchesPattern matches the query string as part of the path", () => {
  assert.equal(matchesPattern("*://*.example.com/watch*", "https://example.com/watch?v=abc"), true);
  assert.equal(matchesPattern("*://*.example.com/watch", "https://example.com/watch?v=abc"), false);
  assert.equal(matchesPattern("*://*.example.com/*", "https://example.com/watch?v=abc"), true);
});

test("matchesPattern rejects unparseable input rather than throwing", () => {
  assert.equal(matchesPattern("*://*.example.com/*", "not a url"), false);
  assert.equal(matchesPattern("*://*.example.com/*", ""), false);
  assert.equal(matchesPattern("*://*.example.com/*", null), false);
  assert.equal(matchesPattern("nonsense", "https://example.com/"), false);
});

test("isSafeSelector allows real CSS and rejects stylesheet escapes", () => {
  const legal = [
    "#feed",
    "main > .item",
    "a ~ b",
    "a + b",
    "div *",
    "[data-testid='primaryColumn']",
    "ytd-app:not([hidden])",
    "a, b",
    ".foo\\:bar",
  ];
  for (const selector of legal) {
    assert.equal(isSafeSelector(selector), true, "should allow " + selector);
  }

  const illegal = [
    "a { color: red } b",
    "a} body{display:block",
    "a; @import url(https://evil.test/x.css)",
    "a</style><script>alert(1)</script>",
    "a */ body {",
    "",
  ];
  for (const selector of illegal) {
    assert.equal(isSafeSelector(selector), false, "should reject " + selector);
  }
  assert.equal(isSafeSelector(null), false);
  assert.equal(isSafeSelector(123), false);
});

test("validateRuleset accepts the fixture", () => {
  const result = validateRuleset(fixture());
  assert.deepEqual(result.errors, []);
  assert.equal(result.ok, true);
});

test("validateRuleset rejects structural problems", () => {
  const cases = [
    [null, "ruleset is not an object"],
    [{}, "sites"],
    [fixture({ schemaVersion: "1" }), "schemaVersion"],
    [fixture({ rulesetVersion: 0 }), "rulesetVersion"],
    [fixture({ sites: [] }), "sites"],
  ];
  for (const [input, expectedFragment] of cases) {
    const result = validateRuleset(input);
    assert.equal(result.ok, false, "expected failure for " + JSON.stringify(input));
    assert.ok(
      result.errors.some((message) => message.includes(expectedFragment)),
      "expected an error mentioning " + expectedFragment + ", got " + JSON.stringify(result.errors)
    );
  }
});

test("validateRuleset rejects duplicate and misnamespaced identifiers", () => {
  const duplicateSite = fixture();
  duplicateSite.sites[1].id = "example";
  assert.ok(validateRuleset(duplicateSite).errors.some((m) => m.includes("duplicate")));

  const duplicateFeature = fixture();
  duplicateFeature.sites[0].features[1].id = "example.feed";
  assert.ok(validateRuleset(duplicateFeature).errors.some((m) => m.includes("duplicate")));

  const wrongNamespace = fixture();
  wrongNamespace.sites[0].features[0].id = "other.feed";
  assert.ok(validateRuleset(wrongNamespace).errors.some((m) => m.includes("namespaced")));

  const badShape = fixture();
  badShape.sites[0].features[0].id = "NotAnId";
  assert.ok(validateRuleset(badShape).errors.some((m) => m.includes("malformed")));
});

test("validateRuleset rejects unsafe selectors and bad patterns", () => {
  const unsafeHide = fixture();
  unsafeHide.sites[0].features[0].hide = ["a { color: red }"];
  assert.ok(validateRuleset(unsafeHide).errors.some((m) => m.includes("unsafe")));

  const unsafeVerify = fixture();
  unsafeVerify.sites[0].features[0].verify = ["a; @import url(x)"];
  assert.ok(validateRuleset(unsafeVerify).errors.some((m) => m.includes("unsafe")));

  const emptyHide = fixture();
  emptyHide.sites[0].features[0].hide = [];
  assert.ok(validateRuleset(emptyHide).errors.some((m) => m.includes("hide")));

  const badPattern = fixture();
  badPattern.sites[0].matches = ["ftp://example.com/*"];
  assert.ok(validateRuleset(badPattern).errors.some((m) => m.includes("match pattern")));

  const emptyAppliesTo = fixture();
  emptyAppliesTo.sites[0].features[0].appliesTo = [];
  assert.ok(validateRuleset(emptyAppliesTo).errors.some((m) => m.includes("appliesTo")));
});

test("siteForURL resolves the right site or nothing at all", () => {
  const ruleset = fixture();
  assert.equal(siteForURL(ruleset, "https://www.example.com/")?.id, "example");
  assert.equal(siteForURL(ruleset, "https://other.test/anything")?.id, "other");
  assert.equal(siteForURL(ruleset, "https://unrelated.test/"), null);
  assert.equal(siteForURL(ruleset, "garbage"), null);
});

test("siteForURL refuses to act on an invalid ruleset", () => {
  const broken = fixture();
  broken.sites[0].features[0].hide = ["a { }"];
  assert.equal(siteForURL(broken, "https://example.com/"), null);
});

test("activeFeatures honours defaultEnabled when there are no preferences", () => {
  const site = fixture().sites[0];
  const ids = activeFeatures(site, "https://example.com/", null).map((f) => f.id);
  assert.deepEqual(ids, ["example.feed"], "comments defaults to off");
});

test("activeFeatures lets preferences override in both directions", () => {
  const site = fixture().sites[0];

  const bothOn = activeFeatures(site, "https://example.com/", { "example.comments": true });
  assert.deepEqual(bothOn.map((f) => f.id), ["example.feed", "example.comments"]);

  const feedOff = activeFeatures(site, "https://example.com/", { "example.feed": false });
  assert.deepEqual(feedOff.map((f) => f.id), []);

  const partial = activeFeatures(site, "https://example.com/", { "unrelated.id": true });
  assert.deepEqual(partial.map((f) => f.id), ["example.feed"], "unknown keys are ignored");
});

test("activeFeatures respects appliesTo path globs", () => {
  const site = fixture().sites[0];
  const on = { "example.comments": true };

  assert.deepEqual(
    activeFeatures(site, "https://example.com/", on).map((f) => f.id),
    ["example.feed", "example.comments"],
    "the feed feature applies on the root path"
  );
  assert.deepEqual(
    activeFeatures(site, "https://example.com/?tab=x", on).map((f) => f.id),
    ["example.feed", "example.comments"],
    "the /?* glob covers a query string on the root"
  );
  assert.deepEqual(
    activeFeatures(site, "https://example.com/watch", on).map((f) => f.id),
    ["example.comments"],
    "the feed feature is scoped away from a watch page"
  );
});

test("activeFeatures survives junk input", () => {
  assert.deepEqual(activeFeatures(null, "https://example.com/", null), []);
  assert.deepEqual(activeFeatures({}, "https://example.com/", null), []);
  const site = fixture().sites[0];
  assert.deepEqual(activeFeatures(site, "not a url", null).map((f) => f.id), [], "no path means no path match");
});

test("buildStylesheet emits one balanced block per feature", () => {
  const site = fixture().sites[0];
  const css = buildStylesheet(activeFeatures(site, "https://example.com/", { "example.comments": true }));

  assert.match(css, /\/\* example\.feed \*\//);
  assert.match(css, /\/\* example\.comments \*\//);
  assert.match(css, /#feed,\nmain > \.feed-item \{ display: none !important; \}/);

  const opens = (css.match(/\{/g) || []).length;
  const closes = (css.match(/\}/g) || []).length;
  assert.equal(opens, 2, "one open brace per feature");
  assert.equal(closes, 2, "braces stay balanced");
});

test("buildStylesheet drops unsafe selectors without dropping the safe ones", () => {
  const features = [
    { id: "a.b", hide: ["#good", "#bad { } body"], defaultEnabled: true },
    { id: "c.d", hide: ["#alsobad; @import url(x)"], defaultEnabled: true },
  ];
  const css = buildStylesheet(features);
  assert.match(css, /#good \{ display: none !important; \}/);
  assert.doesNotMatch(css, /#bad/);
  assert.doesNotMatch(css, /@import/);
  assert.doesNotMatch(css, /c\.d/, "a feature with no safe selectors emits nothing at all");
  assert.equal((css.match(/\{/g) || []).length, 1);
});

test("buildStylesheet handles empty and junk input", () => {
  assert.equal(buildStylesheet([]), "");
  assert.equal(buildStylesheet(null), "");
  assert.equal(buildStylesheet([{ id: "a.b" }]), "");
  assert.equal(buildStylesheet([{ id: "a.b", hide: [] }]), "");
});

test("chooseRuleset prefers a newer valid remote ruleset", () => {
  const bundled = fixture();
  const remote = fixture({ rulesetVersion: 5 });
  const result = chooseRuleset(bundled, remote);
  assert.equal(result.source, "remote");
  assert.equal(result.ruleset.rulesetVersion, 5);
});

test("chooseRuleset falls back to bundled for every failure mode", () => {
  const bundled = fixture();

  const cases = [
    [null, "no remote"],
    [undefined, "no remote"],
    [fixture({ rulesetVersion: 4 }), "not newer"],
    [fixture({ rulesetVersion: 3 }), "not newer"],
    [fixture({ rulesetVersion: 9, schemaVersion: 2 }), "schema"],
    [{ schemaVersion: 1, rulesetVersion: 99 }, "invalid"],
    ["a string", "invalid"],
  ];

  for (const [remote, expectedFragment] of cases) {
    const result = chooseRuleset(bundled, remote);
    assert.equal(result.source, "bundled", "expected fallback for " + JSON.stringify(remote));
    assert.equal(result.ruleset, bundled);
    assert.ok(
      result.reason.includes(expectedFragment),
      "expected reason mentioning " + expectedFragment + ", got: " + result.reason
    );
  }
});

test("chooseRuleset refuses to run at all if the bundled ruleset is broken", () => {
  const broken = fixture();
  broken.sites[0].features[0].hide = ["a { }"];
  const result = chooseRuleset(broken, fixture({ rulesetVersion: 99 }));
  assert.equal(result.source, "none");
  assert.equal(result.ruleset, null);
  assert.match(result.reason, /bundled ruleset is invalid/);
});

test("a remote ruleset cannot smuggle a stylesheet escape past the engine", () => {
  const bundled = fixture();
  const hostile = fixture({ rulesetVersion: 99 });
  hostile.sites[0].features[0].hide = ["#x } body { display: none } .y"];

  const chosen = chooseRuleset(bundled, hostile);
  assert.equal(chosen.source, "bundled", "a hostile remote ruleset never gets adopted");

  // And even if one were adopted by some other path, the stylesheet builder drops it.
  const css = buildStylesheet(hostile.sites[0].features);
  assert.doesNotMatch(css, /body \{ display: none \}/);
});

test("the supported schema version is pinned", () => {
  assert.equal(SUPPORTED_SCHEMA_VERSION, 1);
});
