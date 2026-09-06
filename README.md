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
  fixtures/friction-vectors.json  the one set of vectors both friction mode engines are tested against
Extension/
  Resources/rules-engine.js    pure ruleset logic, shared by the content script and the tests
  Resources/schedule-engine.js pure schedule logic: always on, time windows, named Focus
  Resources/friction-engine.js pure delay-plus-typed-reason logic for the block replacement page
  Resources/content.js         injects the stylesheet, follows single page navigation
  Resources/background.js      picks bundled versus remote ruleset, serves content scripts
  Resources/manifest.json
  tests/                       Node tests for all three engines
Packages/QuietCore/            Swift mirror of all three engines plus BlockSession, used by the
                                Mac and iOS apps
Packages/IndieKit/             Shared licensing logic, reused by all three apps in the portfolio
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

## Focus mode scheduling

Resolved by research, recorded in `../mac-apps/01-quiet.md` section 8a and in memory as
`macos-focus-detection-not-available`: there is no macOS API to ask which Focus is
currently active. The path forward is `SetFocusFilterIntent`, which is push based, so the
user adds Quiet as a Focus Filter for each Focus once in System Settings, and the OS calls
Quiet when that Focus turns on or off. `ScheduleEvaluator` already took the active Focus
identifier list as a plain argument rather than querying for it, so this finding costs no
rework, only a native integration once the Xcode project exists.

## BlockSession and FrictionMode

Two more pure engines for the Mac companion app's blocking session and the Safari
extension's friction mode delay screen.

**`BlockSession`** (Swift only, `QuietCore`) decides whether an app-blocking session is
active and whether it can currently be cancelled. Strict mode's entire premise is that it
refuses cancellation while running; this type is where that refusal is decided, tested at
the exact start and end instants and against a clock rolled backward. It does not by
itself make a session survive a reboot or an app deletion: that is a persistence
responsibility for the app target once it exists.

**`FrictionMode`** (mirrored in JS and Swift) decides whether a delay has elapsed and
whether a typed reason is long enough, both against `Rules/fixtures/friction-vectors.json`
so the two languages are checked against one shared set of cases. Times are seconds since
the epoch rather than `Date` objects, which is what keeps the logic free of timezone
concerns entirely.

## IndieKit

The shared package described in `../mac-apps/README.md`, so it is written once here and
reused by Tally and Redact rather than rebuilt per app. Only the licensing module exists so
far.

**`TrialState` and `LicenseState`** decide whether a customer has full access, given a
purchase flag and an optional time limited trial, evaluated against a supplied `now`
rather than the wall clock. Two models coexist because the three apps do not share one:
Quiet and Redact have a permanently free tier plus a one time unlock (`FeatureGate`), Tally
has a fully functional 14 day trial that then locks (`LicenseState.hasFullAccess`). A
purchase always wins over trial state, including an expired or malformed trial record left
over from before the purchase completed.

A clock set backward, by a user trying to extend a trial or simply by a wrong system
clock, is treated as resetting the trial to fresh rather than producing a negative elapsed
time or an expired result. This is a deliberate product decision, not an oversight: it
costs at most one fresh trial period, and the alternative (aggressively detecting clock
tampering) has a worse failure mode, which is a legitimate customer with a slow-syncing
clock getting locked out.

`PurchaseObserving` is the seam to StoreKit 2. It is a protocol with no implementation
here, because a real implementation is async, talks to Apple's servers, and cannot be unit
tested the way the rest of this package is; an app target implements it against
`Transaction.currentEntitlements` once the Xcode project exists.

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
