# Quiet

A Safari extension that removes the addictive parts of sites you still need, plus a Mac
app that blocks sites and apps outright. One purchase, every Apple device.

Plan and market research: `../mac-apps/01-quiet.md`.

## Layout

```
Rules/
  schema.json                     JSON Schema for a ruleset
  fixtures/ruleset-fixture.json   the one fixture both ruleset engines are tested against
  fixtures/schedule-vectors.json  the one set of vectors both schedule engines are tested against
Extension/
  Resources/rules-engine.js    pure ruleset logic, shared by the content script and the tests
  Resources/schedule-engine.js pure schedule logic: always on, time windows, named Focus
  Resources/content.js         injects the stylesheet, follows single page navigation
  Resources/background.js      picks bundled versus remote ruleset, serves content scripts
  Resources/manifest.json
  tests/                       Node tests for both engines
Packages/QuietCore/            Swift mirror of both engines, used by the Mac and iOS apps
Tools/
  check-ruleset.js             validates every ruleset against the shipping engine
  test.sh                      runs everything that does not need Xcode
```

## Verifying

```
./Tools/test.sh
```

Runs ruleset validation, the JavaScript suite and the Swift suite. The ruleset engines
are exercised against `Rules/fixtures/ruleset-fixture.json` and the schedule engines
against `Rules/fixtures/schedule-vectors.json`, so a behavioural difference between the
JavaScript and Swift implementations of either engine is a test failure rather than a
shipped bug.

## Design notes

**Feature identifiers are permanent.** User preferences are keyed on `site.feature`, so
selectors underneath an identifier can change with every ruleset update without anyone
losing their settings.

**Rulesets are data, never code.** Selectors are validated on both sides of the boundary
and anything that could escape a stylesheet rule is rejected. A remote ruleset is adopted
only when it is valid, speaks the supported schema and is strictly newer than the bundled
copy. Every failure path falls back to the bundled ruleset, so a bad publish cannot take
the extension offline.

**Content script matches are static.** Manifest v3 requires the site list at install time.
Selector fixes for an existing site ship through the ruleset and reach users immediately;
adding a brand new site needs an app update. That trade is deliberate: selector rot is
frequent, new sites are rare.

**Schedule evaluation never touches a timezone.** `ScheduleMoment` / the JS equivalent is
a pre-extracted (weekday, minutes since midnight) pair. Extracting it from `Date`/`Date()`
is the one impure step, isolated to `ScheduleMoment.now` and `momentFromDate`; everything
after that is pure and deterministic, which is what makes the midnight-crossing and
day-boundary cases in `schedule-vectors.json` testable at all. A schedule's `window` kind
names the day a window *starts* on; a window that crosses midnight is resolved by checking
both today's list of days and yesterday's, never by storing two separate entries.

**Focus mode detection is native only.** Neither engine can observe which macOS Focus is
currently active; that requires the container app. The evaluator takes the active Focus
identifiers as a plain argument, so the Mac app becomes responsible for computing them and
pushing the result down to the extension, the same way it will push ruleset updates. That
wiring is not built yet and depends on the Xcode project existing.
