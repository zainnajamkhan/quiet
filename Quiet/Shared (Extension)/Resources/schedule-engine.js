//
//  schedule-engine.js
//  Quiet
//
//  Created by Zain Najam Khan.
//  Copyright © 2026 Zain Najam Khan. All rights reserved.
//

// Pure schedule evaluation: no DOM, no browser APIs, no I/O, no Date construction. This is
// what decides whether a hide-rule or a block-rule is active right now. The "now" it acts
// on is always a pre-extracted ScheduleMoment (weekday plus minutes since midnight), so the
// pure logic here carries no timezone dependency and is exercised identically to the Swift
// engine against Rules/fixtures/schedule-vectors.json.

(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module && module.exports) {
    module.exports = api;
  } else {
    root.QuietSchedule = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const ID = /^[a-z0-9]+(-[a-z0-9]+)*$/;
  const TIME = /^([01][0-9]|2[0-3]):([0-5][0-9])$/;
  const KINDS = new Set(["always", "window", "focus"]);
  const FOCUS_WILDCARD = "*";

  function parseTime(value) {
    const match = TIME.exec(value || "");
    if (!match) return null;
    return Number(match[1]) * 60 + Number(match[2]);
  }

  function isValidDay(day) {
    return Number.isInteger(day) && day >= 1 && day <= 7;
  }

  // The day, in the 1..7 (Sunday..Saturday) numbering, immediately before `weekday`.
  function previousWeekday(weekday) {
    return ((weekday - 2 + 7) % 7) + 1;
  }

  function validateSchedule(schedule) {
    const errors = [];
    const push = (message) => errors.push(message);

    if (!schedule || typeof schedule !== "object" || Array.isArray(schedule)) {
      return { ok: false, errors: ["schedule is not an object"] };
    }
    if (!ID.test(schedule.id || "")) push("id is missing or malformed");
    if (typeof schedule.enabled !== "boolean") push("enabled is not a boolean");
    if (!KINDS.has(schedule.kind)) {
      push("kind must be one of always, window, focus");
      return { ok: errors.length === 0, errors };
    }

    if (schedule.kind === "window") {
      if (!Array.isArray(schedule.windows) || schedule.windows.length === 0) {
        push("windows is required and must be a non empty array for kind window");
      } else {
        schedule.windows.forEach((window, index) => {
          const at = "windows[" + index + "]";
          if (!window || typeof window !== "object") {
            push(at + " is not an object");
            return;
          }
          if (!Array.isArray(window.days) || window.days.length === 0) {
            push(at + ".days is not a non empty array");
          } else {
            if (!window.days.every(isValidDay)) push(at + ".days contains a value outside 1..7");
            if (new Set(window.days).size !== window.days.length) push(at + ".days contains a duplicate");
          }
          const start = parseTime(window.start);
          const end = parseTime(window.end);
          if (start === null) push(at + ".start is not a HH:MM time: " + window.start);
          if (end === null) push(at + ".end is not a HH:MM time: " + window.end);
          if (start !== null && end !== null && start === end) {
            push(at + ".start and .end must not be equal");
          }
        });
      }
    }

    if (schedule.kind === "focus") {
      if (!Array.isArray(schedule.focusIdentifiers) || schedule.focusIdentifiers.length === 0) {
        push("focusIdentifiers is required and must be a non empty array for kind focus");
      } else {
        schedule.focusIdentifiers.forEach((identifier, index) => {
          if (typeof identifier !== "string" || identifier.length === 0) {
            push("focusIdentifiers[" + index + "] is not a non empty string");
          }
        });
      }
    }

    return { ok: errors.length === 0, errors };
  }

  function windowIsActive(window, moment) {
    const start = parseTime(window.start);
    const end = parseTime(window.end);
    if (start === null || end === null || start === end) return false;
    if (!Array.isArray(window.days)) return false;

    const today = window.days.includes(moment.weekday);
    const yesterday = window.days.includes(previousWeekday(moment.weekday));

    if (start < end) {
      // Same day window, e.g. 09:00 to 17:00. Start inclusive, end exclusive.
      return today && moment.minutesSinceMidnight >= start && moment.minutesSinceMidnight < end;
    }

    // Crosses midnight, e.g. 22:00 to 06:00. `days` names the day the window starts on.
    const lateNightPortion = today && moment.minutesSinceMidnight >= start;
    const earlyMorningPortion = yesterday && moment.minutesSinceMidnight < end;
    return lateNightPortion || earlyMorningPortion;
  }

  function isScheduleActive(schedule, moment, activeFocusIdentifiers) {
    const check = validateSchedule(schedule);
    if (!check.ok) return false;
    if (schedule.enabled !== true) return false;
    if (!moment || !isValidDay(moment.weekday) || !Number.isInteger(moment.minutesSinceMidnight)) return false;
    if (moment.minutesSinceMidnight < 0 || moment.minutesSinceMidnight >= 1440) return false;

    switch (schedule.kind) {
      case "always":
        return true;
      case "window":
        return schedule.windows.some((window) => windowIsActive(window, moment));
      case "focus": {
        const active = Array.isArray(activeFocusIdentifiers) ? activeFocusIdentifiers : [];
        if (schedule.focusIdentifiers.includes(FOCUS_WILDCARD)) return active.length > 0;
        return schedule.focusIdentifiers.some((identifier) => active.includes(identifier));
      }
      default:
        return false;
    }
  }

  // Impure: extracts a ScheduleMoment from a JS Date using the system's local time, which is
  // the correct behaviour for a schedule the user set in their own wall clock terms. Kept
  // separate from isScheduleActive so the decision logic itself never touches Date or a
  // timezone, and so tests can supply a moment directly.
  function momentFromDate(date) {
    return {
      weekday: date.getDay() + 1,
      minutesSinceMidnight: date.getHours() * 60 + date.getMinutes(),
    };
  }

  return {
    FOCUS_WILDCARD,
    validateSchedule,
    isScheduleActive,
    momentFromDate,
  };
});
