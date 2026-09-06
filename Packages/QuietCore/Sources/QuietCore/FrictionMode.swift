//
//  FrictionMode.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// Pure logic for the delay-plus-typed-reason gate shown before a blocked page is allowed
/// to load. Mirrors `Extension/Resources/friction-engine.js`, exercised against the same
/// `Rules/fixtures/friction-vectors.json`. Times are seconds since the epoch throughout,
/// so there is no `Date`/timezone involved and no ambiguity between the two engines.
public enum FrictionMode {

    public static let defaultMinimumReasonLength = 3

    /// A clock rolled backward before `startedAt` reads as not complete rather than
    /// complete or negative.
    public static func isDelayComplete(startedAt: TimeInterval, delaySeconds: TimeInterval, now: TimeInterval) -> Bool {
        guard now >= startedAt else { return false }
        return now - startedAt >= delaySeconds
    }

    public static func isReasonValid(_ reason: String, minimumLength: Int = defaultMinimumReasonLength) -> Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumLength
    }
}
