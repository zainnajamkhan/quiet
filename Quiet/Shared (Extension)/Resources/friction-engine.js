//
//  friction-engine.js
//  Quiet
//
//  Created by Zain Najam Khan.
//  Copyright © 2026 Zain Najam Khan. All rights reserved.
//

// Pure logic for friction mode: a delay screen with a typed reason shown before a blocked
// page is allowed to load. No DOM, no timers; the replacement page supplies its own clock
// and re-evaluates on a tick.

(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module && module.exports) {
    module.exports = api;
  } else {
    root.QuietFriction = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const MINIMUM_REASON_LENGTH = 3;

  // Whitespace here matches the intent of a human typed reason, not full Unicode
  // whitespace classification: space, tab, newline and carriage return.
  function trim(value) {
    return String(value).replace(/^[ \t\n\r]+|[ \t\n\r]+$/g, "");
  }

  // `now`, `startedAt` and `delaySeconds` are all in seconds since the epoch, so this has
  // no Date object and no timezone to get wrong. A clock rolled backward before the start
  // reads as not complete rather than complete or negative.
  function isDelayComplete(startedAt, delaySeconds, now) {
    if (typeof startedAt !== "number" || typeof delaySeconds !== "number" || typeof now !== "number") {
      return false;
    }
    if (now < startedAt) return false;
    return now - startedAt >= delaySeconds;
  }

  function isReasonValid(reason, minimumLength) {
    const minimum = typeof minimumLength === "number" ? minimumLength : MINIMUM_REASON_LENGTH;
    if (typeof reason !== "string") return false;
    return trim(reason).length >= minimum;
  }

  return {
    MINIMUM_REASON_LENGTH,
    isDelayComplete,
    isReasonValid,
  };
});
