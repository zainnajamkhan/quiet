# Quiet

A macOS app and Safari extension. It removes the engagement machinery from sites you still
need, and blocks the sites and apps you would rather not open at all.

One purchase, no subscription, no accounts, no analytics.

**Status: feature complete for version one, not submitted.** The only hard blocker is a paid
Apple Developer Program membership. See [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md) for the full
picture, including what is left and the platform facts worth keeping.

## What it does

- **Hide** — feeds, recommendations, comments and Shorts, per site and per feature, across
  six supported sites. Free on two sites at a time.
- **Block** — refuses whole websites, and hides distracting Mac apps. Part of Quiet Pro.

Rules live in a JSON file the app downloads, not in the binary, so a site changing its
markup can be fixed without an App Store release.

## Getting started

```bash
open Quiet/Quiet.xcodeproj    # scheme "Quiet (macOS)"
./Tools/test.sh               # everything that does not need Xcode
```

Safari ships extensions switched off; the app's first run walks through enabling it. Paid
features can be tested for free: `Quiet.storekit` is attached to the scheme, so **Unlock**
completes as a StoreKit test transaction.

## Layout

```
Extension/Resources/   canonical extension sources and the ruleset. Edit here.
Extension/tests/       Node tests for the engines
Rules/                 schema, shared test fixtures, and the published ruleset
Packages/QuietCore/    Swift mirror of the engines, block policy, rule update policy
Packages/IndieKit/     licensing logic, meant for reuse across the app portfolio
Quiet/                 the Xcode project, app sources, and the copies Xcode builds from
Tools/                 test.sh, sync-resources.sh, publish-ruleset.sh, selector tooling
Docs/privacy.md        source of the published privacy policy
```

**Edit `Extension/Resources`, not the copies under `Quiet/`.** Xcode builds from
`Quiet/Shared (Extension)/Resources`, which is a separate file on disk. Run
`Tools/sync-resources.sh` after any change; `Tools/test.sh` fails if the copies drift.

## Tests

```bash
./Tools/test.sh
```

Runs the copy drift guard, ruleset validation against the shipping engine, the Node engine
tests, and both Swift packages. 182 tests. The JavaScript and Swift engines are checked
against the same fixtures so the two implementations cannot quietly disagree.

## Rule updates

Published from the public [`quiet-rules`](https://github.com/zainnajamkhan/quiet-rules)
repository, which also hosts the privacy policy. To ship a fix, bump `rulesetVersion`, run
`Tools/sync-resources.sh`, `Tools/test.sh` and `Tools/publish-ruleset.sh`, then push the
staged file. The publish script refuses a version no installed app would adopt.

## Support

zainnajam2424@gmail.com
