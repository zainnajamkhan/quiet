"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const { validateSchedule, isScheduleActive, momentFromDate, FOCUS_WILDCARD } = require("../Resources/schedule-engine.js");

const VECTORS_PATH = path.join(__dirname, "..", "..", "Rules", "fixtures", "schedule-vectors.json");
const VECTORS = JSON.parse(fs.readFileSync(VECTORS_PATH, "utf8"));

test("schedule-vectors.json is non empty and well formed", () => {
  assert.ok(Array.isArray(VECTORS.cases) && VECTORS.cases.length > 0);
  for (const c of VECTORS.cases) {
    assert.equal(typeof c.description, "string");
    assert.equal(typeof c.expected, "boolean");
  }
});

test("every shared reference vector evaluates as expected", () => {
  for (const c of VECTORS.cases) {
    const got = isScheduleActive(c.schedule, c.moment, c.activeFocusIdentifiers);
    assert.equal(got, c.expected, c.description + " -- schedule: " + JSON.stringify(c.schedule) + ", moment: " + JSON.stringify(c.moment));
  }
});

test("validateSchedule accepts a well formed always schedule", () => {
  assert.deepEqual(validateSchedule({ id: "s", kind: "always", enabled: true }).errors, []);
});

test("validateSchedule accepts a well formed window schedule", () => {
  const schedule = {
    id: "s",
    kind: "window",
    enabled: true,
    windows: [{ days: [2, 3], start: "09:00", end: "17:00" }],
  };
  assert.deepEqual(validateSchedule(schedule).errors, []);
});

test("validateSchedule accepts a well formed focus schedule", () => {
  const schedule = { id: "s", kind: "focus", enabled: true, focusIdentifiers: ["com.apple.focus.work"] };
  assert.deepEqual(validateSchedule(schedule).errors, []);
});

test("validateSchedule rejects structural problems", () => {
  assert.equal(validateSchedule(null).ok, false);
  assert.equal(validateSchedule("nope").ok, false);
  assert.equal(validateSchedule({}).errors.some((m) => m.includes("id")), true);
  assert.equal(validateSchedule({ id: "s", kind: "nonsense", enabled: true }).errors.some((m) => m.includes("kind")), true);
  assert.equal(validateSchedule({ id: "s", kind: "always" }).errors.some((m) => m.includes("enabled")), true);
  assert.equal(validateSchedule({ id: "Bad Id", kind: "always", enabled: true }).errors.some((m) => m.includes("id")), true);
});

test("validateSchedule rejects a window schedule with no windows", () => {
  const result = validateSchedule({ id: "s", kind: "window", enabled: true, windows: [] });
  assert.ok(result.errors.some((m) => m.includes("windows")));
});

test("validateSchedule rejects an out of range or duplicate day", () => {
  const outOfRange = validateSchedule({
    id: "s", kind: "window", enabled: true,
    windows: [{ days: [0, 8], start: "09:00", end: "17:00" }],
  });
  assert.ok(outOfRange.errors.some((m) => m.includes("outside 1..7")));

  const duplicate = validateSchedule({
    id: "s", kind: "window", enabled: true,
    windows: [{ days: [2, 2], start: "09:00", end: "17:00" }],
  });
  assert.ok(duplicate.errors.some((m) => m.includes("duplicate")));
});

test("validateSchedule rejects malformed times and equal start/end", () => {
  const badTime = validateSchedule({
    id: "s", kind: "window", enabled: true,
    windows: [{ days: [2], start: "9:00", end: "17:00" }],
  });
  assert.ok(badTime.errors.some((m) => m.includes(".start")));

  const badEnd = validateSchedule({
    id: "s", kind: "window", enabled: true,
    windows: [{ days: [2], start: "09:00", end: "24:00" }],
  });
  assert.ok(badEnd.errors.some((m) => m.includes(".end")));

  const equal = validateSchedule({
    id: "s", kind: "window", enabled: true,
    windows: [{ days: [2], start: "09:00", end: "09:00" }],
  });
  assert.ok(equal.errors.some((m) => m.includes("must not be equal")));
});

test("validateSchedule rejects a focus schedule with no identifiers", () => {
  const result = validateSchedule({ id: "s", kind: "focus", enabled: true, focusIdentifiers: [] });
  assert.ok(result.errors.some((m) => m.includes("focusIdentifiers")));
});

test("isScheduleActive returns false rather than throwing on an invalid schedule", () => {
  assert.equal(isScheduleActive(null, { weekday: 1, minutesSinceMidnight: 0 }, []), false);
  assert.equal(isScheduleActive({ id: "s", kind: "always", enabled: true }, null, []), false);
  assert.equal(isScheduleActive({ id: "s", kind: "always", enabled: true }, { weekday: 8, minutesSinceMidnight: 0 }, []), false);
  assert.equal(isScheduleActive({ id: "s", kind: "always", enabled: true }, { weekday: 1, minutesSinceMidnight: 1440 }, []), false);
  assert.equal(isScheduleActive({ id: "s", kind: "always", enabled: true }, { weekday: 1, minutesSinceMidnight: -1 }, []), false);
});

test("isScheduleActive treats a missing activeFocusIdentifiers as none active", () => {
  const schedule = { id: "s", kind: "focus", enabled: true, focusIdentifiers: ["com.apple.focus.work"] };
  assert.equal(isScheduleActive(schedule, { weekday: 2, minutesSinceMidnight: 600 }, undefined), false);
});

test("FOCUS_WILDCARD is the literal asterisk the engine checks for", () => {
  assert.equal(FOCUS_WILDCARD, "*");
});

test("momentFromDate extracts local weekday and minutes since midnight", () => {
  // 2026-09-09 is a Wednesday. Constructed with explicit local components so the assertion
  // does not depend on the host machine's timezone offset from UTC.
  const wednesdayMorning = new Date(2026, 8, 9, 9, 5);
  assert.deepEqual(momentFromDate(wednesdayMorning), { weekday: 4, minutesSinceMidnight: 545 });

  const saturdayMidnight = new Date(2026, 8, 12, 0, 0);
  assert.deepEqual(momentFromDate(saturdayMidnight), { weekday: 7, minutesSinceMidnight: 0 });

  const sundayLastMinute = new Date(2026, 8, 6, 23, 59);
  assert.deepEqual(momentFromDate(sundayLastMinute), { weekday: 1, minutesSinceMidnight: 1439 });
});
