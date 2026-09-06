//
//  LicenseState.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// What the UI should say about the customer's access right now. Deliberately excludes
/// `hasFullAccess` details like the exact trial length: that belongs in the trial state
/// itself, not in every call site that wants a yes/no answer.
public enum LicenseStatus: Equatable, Sendable {
    case purchased
    case trialActive(daysRemaining: Int)
    case trialExpired
    /// Never purchased, no trial ever started. This is the resting state for apps like
    /// Quiet and Redact whose free tier has no time limit at all.
    case noTrialNoPurchase
}

/// The full picture: whether a non consumable purchase has been made, and whether a time
/// limited trial exists. Combining both here (rather than letting call sites reimplement
/// "purchased OR trial not expired") is what keeps a purchased customer's access correct
/// even if their trial clock or trial record is in a strange state.
public struct LicenseState: Equatable, Sendable {
    public let isPurchased: Bool
    public let trial: TrialState?

    public init(isPurchased: Bool, trial: TrialState? = nil) {
        self.isPurchased = isPurchased
        self.trial = trial
    }

    public static let unpurchasedNoTrial = LicenseState(isPurchased: false, trial: nil)

    /// A purchase always wins, including over an expired or even a not-yet-started trial
    /// record left over from before the purchase. A trial only grants access while it is
    /// running.
    public func hasFullAccess(asOf now: Date) -> Bool {
        if isPurchased { return true }
        guard let trial else { return false }
        return !trial.isExpired(asOf: now)
    }

    public func status(asOf now: Date) -> LicenseStatus {
        if isPurchased { return .purchased }
        guard let trial else { return .noTrialNoPurchase }
        if trial.isExpired(asOf: now) { return .trialExpired }
        return .trialActive(daysRemaining: trial.daysRemaining(asOf: now))
    }
}
