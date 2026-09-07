//
//  RulesetUpdateTests.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

private let reference = Date(timeIntervalSince1970: 1_800_000_000)

private func ruleset(schemaVersion: Int = 1, rulesetVersion: Int, sites: [Site]? = nil) -> Ruleset {
    Ruleset(
        schemaVersion: schemaVersion,
        rulesetVersion: rulesetVersion,
        sites: sites ?? [
            Site(
                id: "example",
                name: "Example",
                matches: ["*://*.example.com/*"],
                features: [Feature(id: "example.thing", name: "Thing", defaultEnabled: true, hide: ["#thing"])]
            )
        ]
    )
}

private let bundled = ruleset(rulesetVersion: 4)

// MARK: - When to check

@Test func aFreshInstallChecksImmediately() {
    #expect(RulesetUpdatePolicy.isCheckDue(lastCheckedAt: nil, now: reference))
}

@Test func aRecentCheckIsNotRepeated() {
    let anHourAgo = reference.addingTimeInterval(-3600)
    #expect(!RulesetUpdatePolicy.isCheckDue(lastCheckedAt: anHourAgo, now: reference))
}

@Test func theCheckComesDueExactlyOnTheInterval() {
    let exactly = reference.addingTimeInterval(-RulesetUpdatePolicy.checkInterval)
    let justBefore = reference.addingTimeInterval(-RulesetUpdatePolicy.checkInterval + 1)
    #expect(RulesetUpdatePolicy.isCheckDue(lastCheckedAt: exactly, now: reference))
    #expect(!RulesetUpdatePolicy.isCheckDue(lastCheckedAt: justBefore, now: reference))
}

@Test func aClockMovedBackwardsDoesNotDisableUpdatesForever() {
    // Without this, a last check that appears to be in the future never comes due again and
    // the machine silently stops receiving rule fixes.
    let future = reference.addingTimeInterval(60 * 60 * 24 * 365)
    #expect(RulesetUpdatePolicy.isCheckDue(lastCheckedAt: future, now: reference))
}

// MARK: - What to do with what came back

@Test func nothingPublishedIsNotAnError() {
    let outcome = RulesetUpdatePolicy.evaluate(candidate: nil, bundled: bundled, stored: nil)
    #expect(outcome == .unchanged("No rules have been published yet"))
}

@Test func aNewerValidRulesetIsAdopted() {
    let candidate = ruleset(rulesetVersion: 5)
    #expect(RulesetUpdatePolicy.evaluate(candidate: candidate, bundled: bundled, stored: nil) == .adopted(candidate))
}

@Test func aRulesetNoNewerThanTheBundledOneIsIgnored() {
    for version in [3, 4] {
        let outcome = RulesetUpdatePolicy.evaluate(
            candidate: ruleset(rulesetVersion: version), bundled: bundled, stored: nil
        )
        #expect(outcome == .unchanged("Already up to date"))
    }
}

@Test func aRulesetNoNewerThanTheStoredOneIsIgnored() {
    let stored = ruleset(rulesetVersion: 7)
    let outcome = RulesetUpdatePolicy.evaluate(
        candidate: ruleset(rulesetVersion: 7), bundled: bundled, stored: stored
    )
    #expect(outcome == .unchanged("Already up to date"))
}

@Test func aBrokenPublishIsRejectedRatherThanIgnored() {
    // A publish with no sites is structurally invalid. This must read as an alarm, not as
    // "already up to date", because it means something went wrong at publish time.
    let broken = ruleset(rulesetVersion: 9, sites: [])
    let outcome = RulesetUpdatePolicy.evaluate(candidate: broken, bundled: bundled, stored: nil)
    guard case .rejected = outcome else {
        Issue.record("expected rejection, got \(outcome)")
        return
    }
}

@Test func aRulesetForAFutureSchemaIsRejected() {
    let future = ruleset(schemaVersion: Ruleset.supportedSchemaVersion + 1, rulesetVersion: 99)
    let outcome = RulesetUpdatePolicy.evaluate(candidate: future, bundled: bundled, stored: nil)
    guard case .rejected = outcome else {
        Issue.record("expected rejection, got \(outcome)")
        return
    }
}

@Test func aPublishThatSmugglesAStylesheetEscapeIsRejected() {
    // The same escape the JavaScript engine refuses. A remote ruleset is untrusted input:
    // it is the one part of Quiet that a third party could change after install.
    let nasty = Ruleset(
        schemaVersion: 1,
        rulesetVersion: 99,
        sites: [
            Site(
                id: "example",
                name: "Example",
                matches: ["*://*.example.com/*"],
                features: [
                    Feature(
                        id: "example.thing",
                        name: "Thing",
                        defaultEnabled: true,
                        hide: ["#a} body { display: none } #b {"]
                    )
                ]
            )
        ]
    )
    guard case .rejected = RulesetUpdatePolicy.evaluate(candidate: nasty, bundled: bundled, stored: nil) else {
        Issue.record("a stylesheet escape was accepted")
        return
    }
}

// MARK: - Recording the result

@Test func adoptingStoresTheRulesetAndTheTime() {
    let candidate = ruleset(rulesetVersion: 5)
    let state = RulesetUpdatePolicy.apply(.adopted(candidate), to: .empty, now: reference)
    #expect(state.ruleset == candidate)
    #expect(state.lastCheckedAt == reference)
    #expect(state.lastResult == "Updated to rules version 5")
}

@Test func aRejectedPublishNeverDiscardsAGoodStoredRuleset() {
    // The failure this prevents: one bad publish wiping a working ruleset and dropping
    // every user back to whatever shipped in their copy of the app.
    let good = ruleset(rulesetVersion: 6)
    let existing = RulesetUpdateState(ruleset: good, lastCheckedAt: nil, lastResult: nil)
    let state = RulesetUpdatePolicy.apply(.rejected("broken"), to: existing, now: reference)
    #expect(state.ruleset == good)
    #expect(state.lastResult == "broken")
}

@Test func everyOutcomeRecordsTheCheckSoItIsNotRetriedInALoop() {
    for outcome in [RulesetUpdateOutcome.rejected("nope"), .unchanged("fine")] {
        let state = RulesetUpdatePolicy.apply(outcome, to: .empty, now: reference)
        #expect(state.lastCheckedAt == reference)
        #expect(!RulesetUpdatePolicy.isCheckDue(lastCheckedAt: state.lastCheckedAt, now: reference))
    }
}

// MARK: - Persistence

private func temporaryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("quiet-update-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("ruleset-update.json")
}

@Test func updateStateRoundTripsThroughDisk() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let state = RulesetUpdateState(ruleset: ruleset(rulesetVersion: 8), lastCheckedAt: reference, lastResult: "ok")
    try RulesetUpdateStore.save(state, to: url)
    #expect(RulesetUpdateStore.load(from: url) == state)
}

@Test func aCorruptUpdateFileReadsAsNothingRatherThanThrowing() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    #expect(RulesetUpdateStore.load(from: url) == .empty)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{ not json".utf8).write(to: url)
    #expect(RulesetUpdateStore.load(from: url) == .empty)
}

// MARK: - Handing the ruleset to the extension

@Test func anAcceptedRulesetSurvivesTheTripToTheExtension() throws {
    // SafariWebExtensionHandler re-encodes the stored Ruleset and passes it across the
    // native messaging boundary as a plain dictionary. If the encoded key names ever drift
    // from the JSON schema the JavaScript engine validates against, the extension silently
    // rejects every update and quietly keeps using the bundled rules forever.
    let stored = ruleset(rulesetVersion: 11)
    let data = try JSONEncoder().encode(stored)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["schemaVersion"] as? Int == 1)
    #expect(object["rulesetVersion"] as? Int == 11)

    let sites = try #require(object["sites"] as? [[String: Any]])
    let features = try #require(sites.first?["features"] as? [[String: Any]])
    #expect(sites.first?["matches"] as? [String] == ["*://*.example.com/*"])
    #expect(features.first?["hide"] as? [String] == ["#thing"])
    #expect(features.first?["defaultEnabled"] as? Bool == true)

    // And it must decode back into something the selection logic will actually adopt.
    let roundTripped = try Ruleset.decode(from: data)
    #expect(RulesetUpdatePolicy.evaluate(candidate: roundTripped, bundled: bundled, stored: nil) == .adopted(stored))
}
