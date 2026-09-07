//
//  FreeTierPolicy.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// Where the free tier ends and the paid unlock begins.
///
/// The free tier is generous on purpose: hiding works fully on a couple of sites, because
/// nobody buys an extension they have not felt working. The limit is the number of sites
/// in play at once rather than a time trial, so the free tier stays useful forever instead
/// of expiring.
public enum FreeTierPolicy {

    public static let freeSiteLimit = 2

    /// Sites that currently have at least one feature switched on. A site whose features
    /// are all off does not count against the limit, so turning a site off frees a slot.
    public static func sitesInUse(ruleset: Ruleset, preferences: [String: Bool]) -> Set<String> {
        var result: Set<String> = []
        for site in ruleset.sites {
            let anyEnabled = site.features.contains { feature in
                FeatureResolution.isEnabled(feature, preferences: preferences)
            }
            if anyEnabled { result.insert(site.id) }
        }
        return result
    }

    /// Whether switching this feature on is permitted right now. Turning things *off* is
    /// never restricted: locking someone out of disabling a rule would be hostile, and
    /// would also strand a free user who is already over the limit.
    public static func canEnable(
        feature: Feature,
        in site: Site,
        ruleset: Ruleset,
        preferences: [String: Bool],
        isPro: Bool
    ) -> Bool {
        if isPro { return true }
        if FeatureResolution.isEnabled(feature, preferences: preferences) { return true }

        var inUse = sitesInUse(ruleset: ruleset, preferences: preferences)
        if inUse.contains(site.id) { return true }
        inUse.insert(site.id)
        return inUse.count <= freeSiteLimit
    }

    /// Blocking apps and websites is a paid feature in full. The free tier demonstrates
    /// hiding, which is the differentiator; blunt blocking is available free elsewhere.
    public static func canUseBlocking(isPro: Bool) -> Bool {
        isPro
    }

    public static func remainingFreeSites(ruleset: Ruleset, preferences: [String: Bool]) -> Int {
        max(0, freeSiteLimit - sitesInUse(ruleset: ruleset, preferences: preferences).count)
    }
}
