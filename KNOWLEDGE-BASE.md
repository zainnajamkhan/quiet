# Quiet: knowledge base

Everything needed to pick this project back up cold, plus the platform facts that were
expensive to learn and will apply to the next apps.

Last updated 7 September 2026. State: **feature complete for version one, not submitted.**
The only hard blocker is a paid Apple Developer Program membership.

---

## 1. What Quiet is

A macOS app plus a Safari extension.

- **Hide**: removes the engagement machinery from sites you still need (feeds,
  recommendations, comments, Shorts). Per site, per feature toggles.
- **Block**: refuses whole websites, and hides distracting Mac apps, while blocking is on.

Free tier covers hiding on 2 sites. Everything else is a single $24.99 non consumable
purchase. No subscription, no accounts, no analytics.

Six sites supported, 14 features, all selectors verified against live pages.

---

## 2. How to get running

```bash
open Quiet/Quiet.xcodeproj      # scheme "Quiet (macOS)" is shared and configured
./Tools/test.sh                 # everything that does not need Xcode
```

Then in the app: Safari must have the extension switched on (onboarding walks through it).
To test paid features, the scheme already has `Quiet.storekit` attached, so **Unlock**
completes as a fake purchase with no money and no Apple ID.

Reset onboarding to see it again:

```bash
defaults delete com.app.Quiet quiet.onboardingCompleted
```

Shared state lives in `~/Library/Group Containers/CU82DCKHTL.group.com.app.Quiet/`.
Deleting the files there resets settings without reinstalling.

---

## 3. Layout

```
Extension/Resources/     CANONICAL extension sources. Edit here, never the copies.
  rules-engine.js        pure ruleset logic, shared by content script and tests
  schedule-engine.js     pure schedule logic
  content.js             injects the stylesheet, follows single page navigation
  background.js          picks bundled vs remote ruleset, syncs from the app
  ruleset.json           the rules themselves
Extension/tests/         Node tests for the engines
Rules/
  schema.json            JSON Schema for a ruleset
  fixtures/              the one fixture both language engines test against
  published/ruleset.json what gets hosted for rule updates
Packages/QuietCore/      Swift mirror of the engines, plus block policy and update policy
Packages/IndieKit/       licensing logic, meant to be reused by the other apps
Quiet/                   the Xcode project
  macOS (App)/           the app: SwiftUI screens, services, main.swift
  Shared (Extension)/    what Xcode actually builds the extension from (a COPY)
  macOS (App)/Resources/ ruleset copy the app's rule editor reads (a COPY)
Tools/
  test.sh                run everything
  sync-resources.sh      canonical -> the copies Xcode builds
  publish-ruleset.sh     validate and stage a rule update
  check-ruleset.js       validate any ruleset against the shipping engine
  selector-check.js      generated snippet to paste into Safari's console
Docs/privacy.md          source of the published privacy policy
```

### The copies problem

`Extension/Resources` is canonical. Xcode builds from `Quiet/Shared (Extension)/Resources`.
They are different files on disk.

This already caused a real bug: the remote ruleset sync was written, tested and committed
while the built extension contained none of it. Every test passed and the feature did
nothing in the product.

`Tools/test.sh` now fails if any copy drifts. Run `Tools/sync-resources.sh` after editing
anything under `Extension/Resources`.

---

## 4. Architecture, and why

**Pure core, thin shell.** All decision logic lives in `QuietCore` as pure functions taking
their inputs as arguments. The app layer only moves bytes and draws. This is why cutting
Focus mode touched no engine code, and why the rule update admission rules are exhaustively
tested despite the network part being untestable without a paid account.

**One fixture, two languages.** The JavaScript and Swift engines are tested against the same
JSON files in `Rules/fixtures/`. Two implementations that must agree will drift unless they
are checked against one document.

**Protocol seams at the edges.** `RulesetSource` has a CloudKit implementation and an HTTPS
one. `PurchaseObserving` keeps StoreKit out of IndieKit. The untestable thing is always
behind a one method protocol.

**Fail toward the bundled copy.** Every failure in rule delivery leaves the last good
ruleset in place. A bad publish cannot discard a good stored one, and every outcome records
the check time so a broken publish cannot cause a retry loop.

**A remote ruleset is untrusted input.** It is the one part of the app a third party could
change after install. It goes through the same validation as anything else, including a
check for CSS escapes that would let a published rule inject arbitrary styles.

---

## 5. Platform facts that cost real time

These transfer to the other apps. None of them are in the obvious documentation.

### Sandbox and App Groups

- Xcode injects `com.apple.security.app-sandbox` for a macOS app and its extension **even
  with no entitlements file set**. Checking `CODE_SIGN_ENTITLEMENTS` for nil and concluding
  "not sandboxed" is wrong.
- App and extension get separate containers. A plain Application Support path resolves to
  two different files that can never see each other. **App Groups are the only shared
  writable location.**
- macOS App Group ids need the team prefix (`TEAMID.group.com.example.app`); iOS does not.
  Getting this wrong yields a nil container and silently unshared state.
- **App Groups work on a free personal team.** No paid membership needed for this.

### Safari extensions

- Safari ships extensions **disabled** and never prompts. This is the single biggest drop
  off point. Onboarding must handle it.
- `nativeMessaging` permission IS required in the manifest. Safari gates the JS API behind
  it even though Safari has only one possible native host.
- The extension cannot fetch anything if you do not give it network permission, which is a
  good reason to let the app fetch and hand results over by native message.

### App icons

- **The SF Symbols licence forbids using SF Symbols in app icons.** Draw the mark.
- An asset catalog containing only `Contents.json` produces **no `Assets.car` at all**.
  A missing `Assets.car` therefore means "empty catalog", not "excluded from target".

### Xcode 16 synchronized folder groups

- Folders are `PBXFileSystemSynchronizedRootGroup`. New files in them are picked up
  automatically, so no pbxproj edit is needed to add a source file.
- `membershipExceptions` in this project is an **inclusion** list, not an exclusion list.
  Removing a name removes the file from the build.
- The `xcodeproj` Ruby gem removes a target but leaves its exception sets pointing at it,
  then **crashes while serialising**. Detach the exception sets first. The gem writes
  atomically, so a failed save leaves the project file untouched.

### StoreKit

- A `.storekit` file does nothing unless it is attached to the scheme's Run action **and**
  the file is a member of the project. Neither alone is enough. Symptom of either being
  missing is identical: "product not available".
- Schemes are per user unless shared. An unshared scheme cannot carry the StoreKit setting
  into the repository.

### Accessibility permission

- `AXIsProcessTrustedWithOptions(prompt: true)` shows its dialog **only once per app**.
  Afterwards it silently returns false and nothing happens, which reads as a dead button.
  Always offer `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
  as well.
- Still fire the prompt: it is what registers the app in the Accessibility list. An app that
  has never asked may not be listed at all.
- Granting happens in another app, so re check on `didBecomeActive` or the warning stays up
  after the permission was given.
- A sandboxed app **cannot** terminate another app. `NSRunningApplication.terminate()`
  returns false. Hiding via Accessibility is the approvable route.

### App lifecycle

- Removing `Main.storyboard` also removes what instantiates `AppDelegate` and connects it to
  `NSApplication`. The app then launches, stays running, and creates **no windows**. Use an
  explicit `main.swift`.
- `NSHostingView` sizes the window from the SwiftUI content's frame and ignores the window's
  `contentRect`. Setting `contentRect` or `setContentSize` does nothing. Use `idealWidth` and
  `idealHeight` on the root view.
- `.disabled()` on a `List` disables **scrolling** as well as the controls. A locked screen
  taller than the window then cannot be scrolled at all. Disable the rows, not the list.
- `.disabled()` composes with ancestors. A child cannot re enable itself.

### CloudKit

- `CKContainer(identifier:)` **raises** for a container the app is not entitled to. A "try
  CloudKit and fall back" shape crashes on launch instead of degrading. Gate on a nil
  constant until the entitlement genuinely exists.
- CloudKit needs the iCloud entitlement, which needs the paid membership. Plain HTTPS from
  any static host is testable today and is what Quiet actually uses.

### StoreKit, again

- After a successful purchase, **do not re-query `Transaction.currentEntitlements` to decide
  whether the user is now entitled.** It can answer from a stale cache immediately after
  `finish()`, which shows a paywall to somebody who has just paid, with no way forward but
  relaunching. Grant from the transaction you just verified. Keep the
  `Transaction.updates` listener and the launch check as the authority for refunds.

### Free tiers must start inside their own limit

Quiet shipped six sites switched on by default against a two site free limit. Every new
free user was four sites over, so the check that decides whether a rule may be switched on
refused every switched-off rule. The app became one way: you could turn something off and
never turn it back on, and buying Pro was the only escape.

Nothing was wrong with the policy code. The defaults simply violated it on install. There
is now a test that loads the **shipped** ruleset and asserts a fresh install fits inside the
free tier, and a second that asserts anything switchable off is switchable back on.

**The general lesson: test the limits against the data you actually ship, not against a
fixture.** A fixture with two sites passes happily while the real file has six.

### Extension icons are not the app icon

A Safari web extension has its own icons in `Resources/images/`, referenced from
`manifest.json`. Setting the app icon in the asset catalog does nothing for them, so Safari
kept showing Xcode's template icon for months. They also live outside the asset catalog, so
any script that syncs resources has to copy the directory too.

The template also ships `popup.html`, `popup.css`, `popup.js` and `toolbar-icon.svg`. If the
manifest has no `action`, none of them are referenced and all of them are shipping dead.

### Focus modes (feature was cut, research still valid)

- No API tells you which named Focus is running.
- `SetFocusFilterIntent` has `static var current: Self { get async throws }`, so it can be
  pulled as well as pushed. It throws `.notFound` when nothing is applied.
- **Every `@Parameter` must be optional** or deactivation is never delivered: the system has
  no value to supply when a Focus ends, so the call is dropped. Blocking would switch on and
  never switch off.
- `FocusFilterSuggestionContext` is an empty struct. The intent cannot learn which Focus it
  is attached to.

---

## 6. Rule updates

Sites change their markup, so selectors rot. Rules are data, delivered separately from the
app, so a fix does not need an App Store release.

- Published at `https://zainnajamkhan.github.io/quiet-rules/ruleset.json` from the public
  `quiet-rules` repository, which also serves the privacy policy.
- The app checks at most once a day, validates, and installs only a strictly newer version.
- The extension never fetches. It asks the app by native message and caches the answer.

To ship a rule fix:

```bash
# 1. edit Extension/Resources/ruleset.json and BUMP rulesetVersion
./Tools/sync-resources.sh
./Tools/test.sh
./Tools/publish-ruleset.sh          # refuses a version no app would adopt
# 2. copy Rules/published/ruleset.json into the quiet-rules repo and push
```

Verify selectors with `Tools/selector-check.js`: run `./Tools/test.sh` to regenerate it,
then paste it into Safari's console on the site. It distinguishes "this selector is broken"
from "this is not the page I expected".

---

## 7. What is left before shipping

**Blocked on the $99 membership**

1. Distribution signing, App Store Connect record, submission.
2. CloudKit, if ever wanted instead of HTTPS. Not needed.

**Decisions to make**

3. **Bundle id.** Still `com.app.Quiet`, a placeholder, and **permanent after first
   submission**. `com.zainnajamkhan.quiet` needs no domain purchase.
   Do this **after** the membership: the App Group id embeds the Team ID, and a paid account
   may issue a different one. Changing it touches both entitlements files,
   `SharedStateStore`, `ExtensionStatusModel`, `PurchaseModel` and the build settings.
4. **App Store display name.** "Quiet" may be taken. This is separate from the bundle id and
   can be changed later.

**Still to produce**

5. Screenshots for the listing.
6. App Store description.

**Known and accepted**

- `get-task-allow` appears in local Release builds. Xcode strips it when archiving with a
  distribution certificate. Not a problem, but verify at archive time.
- App blocking is suppression, not prevention: a determined user can reopen a hidden app.
  This is described honestly in the UI and matches what comparable tools achieve.

---

## 8. Reusable for the next apps

- `Packages/IndieKit` — trial and licence state, purchase seam, no StoreKit dependency.
- `Tools/test.sh` — the one command that runs everything, including a drift guard.
- The pure core plus thin shell split, and shared cross language fixtures.
- Section 5 above. Most of it is not app specific.

Portfolio plan and market research: `../mac-apps/README.md` and `../mac-apps/01-quiet.md`.
