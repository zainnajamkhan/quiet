//
//  FreeTierPolicyTests.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

private func site(_ id: String, features: [(String, Bool)]) -> Site {
    Site(
        id: id,
        name: id,
        matches: ["*://\(id).test/*"],
        features: features.map { Feature(id: "\(id).\($0.0)", name: $0.0, defaultEnabled: $0.1, hide: ["#x"]) }
    )
}

private let threeSites = Ruleset(
    schemaVersion: 1,
    rulesetVersion: 1,
    sites: [
        site("alpha", features: [("one", false), ("two", false)]),
        site("beta", features: [("one", false)]),
        site("gamma", features: [("one", false)]),
    ]
)

private func feature(_ id: String, in ruleset: Ruleset) -> (Feature, Site) {
    for s in ruleset.sites {
        if let f = s.features.first(where: { $0.id == id }) { return (f, s) }
    }
    fatalError("no such feature: \(id)")
}

@Test func noSitesAreInUseWhenEverythingIsOff() {
    #expect(FreeTierPolicy.sitesInUse(ruleset: threeSites, preferences: [:]).isEmpty)
    #expect(FreeTierPolicy.remainingFreeSites(ruleset: threeSites, preferences: [:]) == 2)
}

@Test func aSiteCountsOnceRegardlessOfHowManyFeaturesAreOn() {
    let prefs = ["alpha.one": true, "alpha.two": true]
    #expect(FreeTierPolicy.sitesInUse(ruleset: threeSites, preferences: prefs) == ["alpha"])
    #expect(FreeTierPolicy.remainingFreeSites(ruleset: threeSites, preferences: prefs) == 1)
}

@Test func aFreeUserCanEnableUpToTwoSites() {
    let (betaOne, betaSite) = feature("beta.one", in: threeSites)
    #expect(FreeTierPolicy.canEnable(
        feature: betaOne, in: betaSite, ruleset: threeSites,
        preferences: ["alpha.one": true], isPro: false
    ), "second site should be allowed")
}

@Test func aFreeUserIsBlockedFromAThirdSite() {
    let (gammaOne, gammaSite) = feature("gamma.one", in: threeSites)
    #expect(!FreeTierPolicy.canEnable(
        feature: gammaOne, in: gammaSite, ruleset: threeSites,
        preferences: ["alpha.one": true, "beta.one": true], isPro: false
    ))
}

@Test func moreFeaturesOnAnAlreadyUsedSiteStayAllowedAtTheLimit() {
    // alpha and beta are in use, so the limit is reached, but alpha.two is on a site
    // already counted and must not be blocked.
    let (alphaTwo, alphaSite) = feature("alpha.two", in: threeSites)
    #expect(FreeTierPolicy.canEnable(
        feature: alphaTwo, in: alphaSite, ruleset: threeSites,
        preferences: ["alpha.one": true, "beta.one": true], isPro: false
    ))
}

@Test func turningSomethingOffIsNeverRestricted() {
    // An already enabled feature always returns true, which is what lets the UI keep the
    // toggle interactive so a free user over the limit can switch things back off.
    let (alphaOne, alphaSite) = feature("alpha.one", in: threeSites)
    #expect(FreeTierPolicy.canEnable(
        feature: alphaOne, in: alphaSite, ruleset: threeSites,
        preferences: ["alpha.one": true, "beta.one": true, "gamma.one": true], isPro: false
    ))
}

@Test func proHasNoSiteLimit() {
    let (gammaOne, gammaSite) = feature("gamma.one", in: threeSites)
    #expect(FreeTierPolicy.canEnable(
        feature: gammaOne, in: gammaSite, ruleset: threeSites,
        preferences: ["alpha.one": true, "beta.one": true], isPro: true
    ))
}

@Test func blockingIsPaidOnly() {
    #expect(!FreeTierPolicy.canUseBlocking(isPro: false))
    #expect(FreeTierPolicy.canUseBlocking(isPro: true))
}

@Test func defaultEnabledFeaturesCountTowardsTheLimit() {
    // The shipped ruleset turns some features on by default, so a fresh install can
    // already be at or over the limit. That must be reflected rather than ignored.
    let defaultsOn = Ruleset(
        schemaVersion: 1, rulesetVersion: 1,
        sites: [
            site("alpha", features: [("one", true)]),
            site("beta", features: [("one", true)]),
            site("gamma", features: [("one", false)]),
        ]
    )
    #expect(FreeTierPolicy.sitesInUse(ruleset: defaultsOn, preferences: [:]) == ["alpha", "beta"])
    let (gammaOne, gammaSite) = feature("gamma.one", in: defaultsOn)
    #expect(!FreeTierPolicy.canEnable(
        feature: gammaOne, in: gammaSite, ruleset: defaultsOn, preferences: [:], isPro: false
    ))
}

// MARK: - The ruleset that actually ships

private func shippedRuleset() throws -> Ruleset {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let url = root
        .appendingPathComponent("Extension")
        .appendingPathComponent("Resources")
        .appendingPathComponent("ruleset.json")
    return try Ruleset.decode(from: try Data(contentsOf: url))
}

@Test func aFreshInstallStartsInsideTheFreeTier() throws {
    // This shipped broken. Six sites were switched on by default against a two site free
    // limit, so a new free user was already four sites over. canEnable() then refused every
    // switched-off toggle, and the app became one way: you could turn a rule off and never
    // turn it back on.
    let ruleset = try shippedRuleset()
    let inUse = FreeTierPolicy.sitesInUse(ruleset: ruleset, preferences: [:])

    #expect(
        inUse.count <= FreeTierPolicy.freeSiteLimit,
        "a fresh install uses \(inUse.count) sites against a limit of \(FreeTierPolicy.freeSiteLimit): \(inUse.sorted())"
    )
}

@Test func aFreeUserCanAlwaysTurnASwitchedOffRuleBackOn() throws {
    // The trap was not the limit itself but that it could not be escaped. Starting from the
    // shipped defaults, switching a rule off must leave the user able to switch it on again.
    let ruleset = try shippedRuleset()
    var preferences: [String: Bool] = [:]

    for site in ruleset.sites {
        for feature in site.features where FeatureResolution.isEnabled(feature, preferences: preferences) {
            preferences[feature.id] = false
            #expect(
                FreeTierPolicy.canEnable(
                    feature: feature, in: site, ruleset: ruleset,
                    preferences: preferences, isPro: false
                ),
                "\(feature.id) could be switched off but not back on"
            )
            preferences[feature.id] = true
        }
    }
}

@Test func buyingProUnlocksEveryFeatureRegardlessOfWhatIsOn() throws {
    let ruleset = try shippedRuleset()
    // Everything switched off, which is the worst case for the free tier counter.
    var preferences: [String: Bool] = [:]
    for site in ruleset.sites {
        for feature in site.features { preferences[feature.id] = false }
    }

    for site in ruleset.sites {
        for feature in site.features {
            #expect(FreeTierPolicy.canEnable(
                feature: feature, in: site, ruleset: ruleset,
                preferences: preferences, isPro: true
            ), "\(feature.id) stayed locked for a paying customer")
        }
    }
}
