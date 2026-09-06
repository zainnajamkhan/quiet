//
//  QuietCoreTests.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

private enum Fixtures {

    /// Rules/fixtures/ruleset-fixture.json is the same file the JavaScript suite loads, so
    /// the two engines are checked against one document rather than two copies that drift.
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func sharedRuleset() throws -> Ruleset {
        let url = repositoryRoot
            .appendingPathComponent("Rules")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("ruleset-fixture.json")
        let data = try Data(contentsOf: url)
        return try Ruleset.decode(from: data)
    }

    static func feature(
        id: String = "example.thing",
        name: String = "Thing",
        defaultEnabled: Bool = true,
        appliesTo: [String]? = nil,
        hide: [String] = ["#thing"],
        verify: [String]? = nil
    ) -> Feature {
        Feature(
            id: id,
            name: name,
            defaultEnabled: defaultEnabled,
            appliesTo: appliesTo,
            hide: hide,
            verify: verify
        )
    }

    static func ruleset(
        schemaVersion: Int = 1,
        rulesetVersion: Int = 4,
        sites: [Site]? = nil
    ) -> Ruleset {
        Ruleset(
            schemaVersion: schemaVersion,
            rulesetVersion: rulesetVersion,
            sites: sites ?? [
                Site(
                    id: "example",
                    name: "Example",
                    matches: ["*://*.example.com/*"],
                    features: [feature()]
                )
            ]
        )
    }
}

// MARK: - Shared fixture

@Test func sharedFixtureDecodesToTheExpectedShape() throws {
    let ruleset = try Fixtures.sharedRuleset()

    #expect(ruleset.schemaVersion == 1)
    #expect(ruleset.rulesetVersion == 4)
    #expect(ruleset.sites.map(\.id) == ["example", "other"])
    #expect(ruleset.allFeatures.map(\.id) == ["example.feed", "example.comments", "other.sidebar"])

    let feed = try #require(ruleset.site(withID: "example")?.features.first)
    #expect(feed.defaultEnabled == true)
    #expect(feed.appliesTo == ["/", "/?*"])
    #expect(feed.hide == ["#feed", "main > .feed-item"])
    #expect(feed.verify == ["main"])

    let comments = try #require(ruleset.allFeatures.first { $0.id == "example.comments" })
    #expect(comments.defaultEnabled == false)
    #expect(comments.appliesTo == nil)
}

@Test func sharedFixtureIsValid() throws {
    #expect(RulesetValidator.validate(try Fixtures.sharedRuleset()).isEmpty)
}

@Test func sharedFixtureRoundTripsThroughCoding() throws {
    let original = try Fixtures.sharedRuleset()
    let encoded = try JSONEncoder().encode(original)
    #expect(try Ruleset.decode(from: encoded) == original)
}

// MARK: - Match patterns

@Test func matchPatternParsingAcceptsWellFormedPatterns() throws {
    let wildcard = try #require(MatchPattern("*://*.example.com/*"))
    #expect(wildcard.scheme == .any)
    #expect(wildcard.host == "*.example.com")
    #expect(wildcard.path == "/*")

    let exact = try #require(MatchPattern("https://a.test/path/*"))
    #expect(exact.scheme == .https)
    #expect(exact.host == "a.test")
    #expect(exact.path == "/path/*")
}

@Test(arguments: [
    "ftp://a.test/*",
    "https://a.test",
    "*.example.com/*",
    "://example.com/*",
    "",
    "nonsense",
])
func matchPatternParsingRejectsMalformedPatterns(pattern: String) {
    #expect(MatchPattern(pattern) == nil)
}

@Test func matchPatternHandlesSchemesHostsAndPaths() throws {
    let pattern = try #require(MatchPattern("*://*.example.com/*"))
    #expect(pattern.matches("https://www.example.com/"))
    #expect(pattern.matches("http://example.com/watch?v=1"))
    #expect(!pattern.matches("ftp://example.com/"))
    #expect(!pattern.matches("file:///Users/x/example.com"))

    let httpsOnly = try #require(MatchPattern("https://example.com/*"))
    #expect(!httpsOnly.matches("http://example.com/"))
}

@Test func matchPatternIsNotFooledByLookalikeHosts() throws {
    let pattern = try #require(MatchPattern("*://*.example.com/*"))
    #expect(!pattern.matches("https://notexample.com/"))
    #expect(!pattern.matches("https://example.com.evil.test/"))
    #expect(pattern.matches("https://example.com/"))
    #expect(pattern.matches("https://deep.sub.example.com/"))

    let exact = try #require(MatchPattern("https://example.com/*"))
    #expect(!exact.matches("https://sub.example.com/"))
}

@Test func matchPatternIsCaseInsensitiveOnTheHostOnly() throws {
    let anyPath = try #require(MatchPattern("*://*.example.com/*"))
    #expect(anyPath.matches("https://WWW.EXAMPLE.COM/Path"))

    let casedPath = try #require(MatchPattern("*://*.example.com/Path"))
    #expect(casedPath.matches("https://example.com/Path"))
    #expect(!casedPath.matches("https://example.com/path"))
}

@Test func matchPatternTreatsTheQueryAsPartOfThePath() throws {
    let prefix = try #require(MatchPattern("*://*.example.com/watch*"))
    #expect(prefix.matches("https://example.com/watch?v=abc"))

    let exactPath = try #require(MatchPattern("*://*.example.com/watch"))
    #expect(!exactPath.matches("https://example.com/watch?v=abc"))
}

@Test func matchPatternNormalisesAnEmptyPathToRoot() throws {
    let pattern = try #require(MatchPattern("*://*.example.com/"))
    #expect(pattern.matches("https://example.com"))
    #expect(pattern.matches("https://example.com/"))
}

@Test(arguments: ["not a url", "", "example.com/path", "/just/a/path"])
func matchPatternRejectsUnparseableURLs(url: String) throws {
    let pattern = try #require(MatchPattern("*://*.example.com/*"))
    #expect(!pattern.matches(url))
}

// MARK: - Selector safety

@Test(arguments: [
    "#feed",
    "main > .item",
    "a ~ b",
    "a + b",
    "div *",
    "[data-testid='primaryColumn']",
    "ytd-app:not([hidden])",
    "a, b",
    #".foo\:bar"#,
])
func safeSelectorsAreAccepted(selector: String) {
    #expect(RulesetValidator.isSafeSelector(selector))
}

@Test(arguments: [
    "a { color: red } b",
    "a} body{display:block",
    "a; @import url(https://evil.test/x.css)",
    "a</style><script>alert(1)</script>",
    "a */ body {",
    "",
])
func unsafeSelectorsAreRejected(selector: String) {
    #expect(!RulesetValidator.isSafeSelector(selector))
}

@Test(arguments: ["example", "you-tube", "a1", "x-1-y"])
func wellFormedIdentifiersAreAccepted(identifier: String) {
    #expect(RulesetValidator.isValidIdentifier(identifier))
}

@Test(arguments: ["", "-a", "a-", "a--b", "Example", "ex ample", "ex.ample", "café"])
func malformedIdentifiersAreRejected(identifier: String) {
    #expect(!RulesetValidator.isValidIdentifier(identifier))
}

// MARK: - Validation

@Test func validationRejectsDuplicateAndMisnamespacedIdentifiers() {
    let duplicateSite = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://a.test/*"], features: [Fixtures.feature()]),
        Site(id: "example", name: "B", matches: ["*://b.test/*"], features: [Fixtures.feature(id: "example.other")]),
    ])
    #expect(RulesetValidator.validate(duplicateSite).contains { $0.contains("duplicate") })

    let duplicateFeature = Fixtures.ruleset(sites: [
        Site(
            id: "example",
            name: "A",
            matches: ["*://a.test/*"],
            features: [Fixtures.feature(), Fixtures.feature()]
        )
    ])
    #expect(RulesetValidator.validate(duplicateFeature).contains { $0.contains("duplicate") })

    let wrongNamespace = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://a.test/*"], features: [Fixtures.feature(id: "other.thing")])
    ])
    #expect(RulesetValidator.validate(wrongNamespace).contains { $0.contains("namespaced") })

    let badShape = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://a.test/*"], features: [Fixtures.feature(id: "NotAnId")])
    ])
    #expect(RulesetValidator.validate(badShape).contains { $0.contains("malformed") })
}

@Test func validationRejectsUnsafeSelectorsAndBadPatterns() {
    let unsafeHide = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://a.test/*"], features: [Fixtures.feature(hide: ["a { color: red }"])])
    ])
    #expect(RulesetValidator.validate(unsafeHide).contains { $0.contains("unsafe") })

    let unsafeVerify = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://a.test/*"], features: [Fixtures.feature(verify: ["a; @import url(x)"])])
    ])
    #expect(RulesetValidator.validate(unsafeVerify).contains { $0.contains("unsafe") })

    let emptyHide = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://a.test/*"], features: [Fixtures.feature(hide: [])])
    ])
    #expect(RulesetValidator.validate(emptyHide).contains { $0.contains("hide") })

    let badPattern = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["ftp://a.test/*"], features: [Fixtures.feature()])
    ])
    #expect(RulesetValidator.validate(badPattern).contains { $0.contains("match pattern") })

    let emptyAppliesTo = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://a.test/*"], features: [Fixtures.feature(appliesTo: [])])
    ])
    #expect(RulesetValidator.validate(emptyAppliesTo).contains { $0.contains("appliesTo") })

    let noSites = Ruleset(schemaVersion: 1, rulesetVersion: 1, sites: [])
    #expect(RulesetValidator.validate(noSites).contains { $0.contains("sites") })

    let badVersion = Fixtures.ruleset(rulesetVersion: 0)
    #expect(RulesetValidator.validate(badVersion).contains { $0.contains("rulesetVersion") })
}

// MARK: - Feature resolution

@Test func siteLookupResolvesTheRightSiteOrNothing() throws {
    let ruleset = try Fixtures.sharedRuleset()
    #expect(FeatureResolution.site(in: ruleset, matching: "https://www.example.com/")?.id == "example")
    #expect(FeatureResolution.site(in: ruleset, matching: "https://other.test/anything")?.id == "other")
    #expect(FeatureResolution.site(in: ruleset, matching: "https://unrelated.test/") == nil)
    #expect(FeatureResolution.site(in: ruleset, matching: "garbage") == nil)
}

@Test func siteLookupRefusesToActOnAnInvalidRuleset() {
    let broken = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://*.example.com/*"], features: [Fixtures.feature(hide: ["a { }"])])
    ])
    #expect(FeatureResolution.site(in: broken, matching: "https://example.com/") == nil)
}

@Test func activeFeaturesHonourDefaultsThenPreferences() throws {
    let site = try #require(Fixtures.sharedRuleset().site(withID: "example"))

    let defaults = FeatureResolution.activeFeatures(in: site, url: "https://example.com/", preferences: [:])
    #expect(defaults.map(\.id) == ["example.feed"])

    let bothOn = FeatureResolution.activeFeatures(
        in: site,
        url: "https://example.com/",
        preferences: ["example.comments": true]
    )
    #expect(bothOn.map(\.id) == ["example.feed", "example.comments"])

    let feedOff = FeatureResolution.activeFeatures(
        in: site,
        url: "https://example.com/",
        preferences: ["example.feed": false]
    )
    #expect(feedOff.isEmpty)

    let unknownKey = FeatureResolution.activeFeatures(
        in: site,
        url: "https://example.com/",
        preferences: ["unrelated.id": true]
    )
    #expect(unknownKey.map(\.id) == ["example.feed"])
}

@Test func activeFeaturesRespectAppliesToGlobs() throws {
    let site = try #require(Fixtures.sharedRuleset().site(withID: "example"))
    let on = ["example.comments": true]

    #expect(
        FeatureResolution.activeFeatures(in: site, url: "https://example.com/", preferences: on).map(\.id)
            == ["example.feed", "example.comments"]
    )
    #expect(
        FeatureResolution.activeFeatures(in: site, url: "https://example.com/?tab=x", preferences: on).map(\.id)
            == ["example.feed", "example.comments"]
    )
    #expect(
        FeatureResolution.activeFeatures(in: site, url: "https://example.com/watch", preferences: on).map(\.id)
            == ["example.comments"]
    )
}

@Test func activeFeaturesSurviveJunkURLs() throws {
    let site = try #require(Fixtures.sharedRuleset().site(withID: "example"))
    #expect(FeatureResolution.activeFeatures(in: site, url: "not a url", preferences: [:]).isEmpty)
}

// MARK: - Ruleset selection

@Test func selectionPrefersANewerValidRemoteRuleset() {
    let outcome = RulesetSelection.choose(bundled: Fixtures.ruleset(), remote: Fixtures.ruleset(rulesetVersion: 5))
    #expect(outcome.source == .remote)
    #expect(outcome.ruleset?.rulesetVersion == 5)
}

@Test func selectionFallsBackToBundledForEveryFailureMode() {
    let bundled = Fixtures.ruleset()

    let cases: [(Ruleset?, String)] = [
        (nil, "no remote"),
        (Fixtures.ruleset(rulesetVersion: 4), "not newer"),
        (Fixtures.ruleset(rulesetVersion: 3), "not newer"),
        (Fixtures.ruleset(schemaVersion: 2, rulesetVersion: 9), "schema"),
        (Ruleset(schemaVersion: 1, rulesetVersion: 99, sites: []), "invalid"),
    ]

    for (remote, fragment) in cases {
        let outcome = RulesetSelection.choose(bundled: bundled, remote: remote)
        #expect(outcome.source == .bundled, "expected fallback, reason was: \(outcome.reason)")
        #expect(outcome.ruleset == bundled)
        #expect(outcome.reason.contains(fragment), "expected reason mentioning \(fragment), got: \(outcome.reason)")
    }
}

@Test func selectionRefusesToRunOnABrokenBundledRuleset() {
    let broken = Fixtures.ruleset(sites: [
        Site(id: "example", name: "A", matches: ["*://a.test/*"], features: [Fixtures.feature(hide: ["a { }"])])
    ])
    let outcome = RulesetSelection.choose(bundled: broken, remote: Fixtures.ruleset(rulesetVersion: 99))
    #expect(outcome.source == .none)
    #expect(outcome.ruleset == nil)
    #expect(outcome.reason.contains("bundled ruleset is invalid"))
}

@Test func aHostileRemoteRulesetIsNeverAdopted() {
    let hostile = Fixtures.ruleset(
        rulesetVersion: 99,
        sites: [
            Site(
                id: "example",
                name: "A",
                matches: ["*://*.example.com/*"],
                features: [Fixtures.feature(hide: ["#x } body { display: none } .y"])]
            )
        ]
    )
    let outcome = RulesetSelection.choose(bundled: Fixtures.ruleset(), remote: hostile)
    #expect(outcome.source == .bundled)
}
