"use strict";

// Exercises Tools/selector-check.js against simulated DOMs. The snippet is what tells a
// genuinely broken selector apart from "you are simply not on that page", so its status
// logic being wrong would be worse than having no verifier at all.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const SNIPPET_PATH = path.join(__dirname, "..", "..", "Tools", "selector-check.js");
const snippet = fs.readFileSync(SNIPPET_PATH, "utf8");

function runWith({ hostname, pathname, search, selectorCounts }) {
  const logs = [];
  const tables = [];
  const fakeLocation = { hostname, pathname, search };
  const fakeDocument = {
    querySelectorAll(sel) {
      if (Object.prototype.hasOwnProperty.call(selectorCounts, sel)) {
        const n = selectorCounts[sel];
        if (n === "throw") throw new Error("bad selector");
        return { length: n };
      }
      return { length: 0 };
    },
  };
  const fakeConsole = {
    log: (...a) => logs.push(a.join(" ")),
    table: (rows) => tables.push(rows),
  };
  const fn = new Function("location", "document", "console", snippet);
  fn(fakeLocation, fakeDocument, fakeConsole);
  return { logs, rows: tables[0] || [] };
}

test("an unknown host is reported rather than silently ignored", () => {
  const { logs } = runWith({ hostname: "example.org", pathname: "/", search: "", selectorCounts: {} });
  assert.ok(logs.some((l) => l.includes("no rules defined")));
});

test("a fully present YouTube home page reports ok", () => {
  const { rows } = runWith({
    hostname: "www.youtube.com",
    pathname: "/",
    search: "",
    selectorCounts: {
      "ytd-app": 1,
      "ytd-rich-grid-renderer": 1,
      "ytd-reel-shelf-renderer": 2,
      "#comments": 1,
    },
  });
  const homeFeed = rows.find((r) => r.selector === "ytd-rich-grid-renderer");
  assert.ok(homeFeed, "expected a row for the home feed selector");
  assert.ok(homeFeed.status.startsWith("ok"), "got: " + homeFeed.status);
});

test("a selector matching nothing on a recognised page is flagged BROKEN", () => {
  const { rows } = runWith({
    hostname: "www.youtube.com",
    pathname: "/",
    search: "",
    selectorCounts: { "ytd-app": 1, "ytd-rich-grid-renderer": 0 },
  });
  const homeFeed = rows.find((r) => r.selector === "ytd-rich-grid-renderer");
  assert.ok(homeFeed.status.includes("BROKEN"), "got: " + homeFeed.status);
});

test("an unrecognised page is distinguished from a broken selector", () => {
  const { rows } = runWith({
    hostname: "www.youtube.com",
    pathname: "/",
    search: "",
    selectorCounts: { "ytd-app": 0, "ytd-rich-grid-renderer": 0 },
  });
  const homeFeed = rows.find((r) => r.selector === "ytd-rich-grid-renderer");
  assert.ok(homeFeed.status.includes("NOT RECOGNISED"), "got: " + homeFeed.status);
});

test("appliesTo is respected: the home feed rule is n/a on a watch page", () => {
  const { rows } = runWith({
    hostname: "www.youtube.com",
    pathname: "/watch",
    search: "?v=abc",
    selectorCounts: { "ytd-app": 1, "ytd-rich-grid-renderer": 0, "#comments": 1 },
  });
  const homeFeed = rows.find((r) => r.selector === "ytd-rich-grid-renderer");
  const comments = rows.find((r) => r.selector === "#comments");
  assert.ok(homeFeed.status.includes("n/a"), "home feed got: " + homeFeed.status);
  assert.ok(comments.status.startsWith("ok"), "comments got: " + comments.status);
});

test("an invalid selector is caught rather than crashing the run", () => {
  const { rows } = runWith({
    hostname: "www.youtube.com",
    pathname: "/",
    search: "",
    selectorCounts: { "ytd-app": 1, "ytd-rich-grid-renderer": "throw" },
  });
  const homeFeed = rows.find((r) => r.selector === "ytd-rich-grid-renderer");
  assert.ok(homeFeed.status.includes("INVALID"), "got: " + homeFeed.status);
});

test("x.com resolves through its own match pattern", () => {
  const { rows } = runWith({
    hostname: "x.com",
    pathname: "/home",
    search: "",
    selectorCounts: { '[data-testid="primaryColumn"]': 1, '[data-testid="sidebarColumn"]': 1 },
  });
  const sidebar = rows.find((r) => r.feature === "x.sidebar");
  assert.ok(sidebar, "expected an x.sidebar row");
  assert.ok(sidebar.status.startsWith("ok"), "got: " + sidebar.status);
});

test("twitter.com also resolves to the x rules", () => {
  const { rows } = runWith({
    hostname: "twitter.com",
    pathname: "/home",
    search: "",
    selectorCounts: { '[data-testid="primaryColumn"]': 1, '[data-testid="sidebarColumn"]': 1 },
  });
  assert.ok(rows.some((r) => r.feature === "x.sidebar"));
});
