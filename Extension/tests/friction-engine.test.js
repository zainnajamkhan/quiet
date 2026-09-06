"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const { MINIMUM_REASON_LENGTH, isDelayComplete, isReasonValid } = require("../Resources/friction-engine.js");

const VECTORS_PATH = path.join(__dirname, "..", "..", "Rules", "fixtures", "friction-vectors.json");
const VECTORS = JSON.parse(fs.readFileSync(VECTORS_PATH, "utf8"));

test("every shared delay vector evaluates as expected", () => {
  for (const c of VECTORS.delayCases) {
    assert.equal(isDelayComplete(c.startedAt, c.delaySeconds, c.now), c.expected, c.description);
  }
});

test("every shared reason vector evaluates as expected", () => {
  for (const c of VECTORS.reasonCases) {
    assert.equal(isReasonValid(c.reason), c.expected, c.description);
  }
});

test("isDelayComplete rejects non numeric input rather than throwing", () => {
  assert.equal(isDelayComplete(null, 10, 1000), false);
  assert.equal(isDelayComplete(1000, "10", 1010), false);
  assert.equal(isDelayComplete(1000, 10, undefined), false);
  assert.equal(isDelayComplete(1000, 10, "1010"), false);
});

test("isReasonValid rejects non string input rather than throwing", () => {
  assert.equal(isReasonValid(null), false);
  assert.equal(isReasonValid(undefined), false);
  assert.equal(isReasonValid(42), false);
  assert.equal(isReasonValid({}), false);
});

test("isReasonValid honours a custom minimum length", () => {
  assert.equal(isReasonValid("ab", 2), true);
  assert.equal(isReasonValid("a", 2), false);
  assert.equal(isReasonValid("", 0), true, "a zero minimum accepts an empty reason");
});

test("MINIMUM_REASON_LENGTH is the documented default", () => {
  assert.equal(MINIMUM_REASON_LENGTH, 3);
});
