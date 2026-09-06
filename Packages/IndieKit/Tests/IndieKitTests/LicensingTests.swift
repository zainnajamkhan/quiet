//
//  LicensingTests.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import IndieKit

private let reference = Date(timeIntervalSince1970: 1_800_000_000) // fixed instant, no "now" in tests

// MARK: - TrialState

@Test func trialIsNotExpiredAtItsOwnStart() {
    let trial = TrialState.days(14, from: reference)
    #expect(!trial.isExpired(asOf: reference))
    #expect(trial.daysRemaining(asOf: reference) == 14)
}

@Test func trialMidwayThroughReportsTheCorrectDaysRemaining() {
    let trial = TrialState.days(14, from: reference)
    let sevenDaysIn = reference.addingTimeInterval(7 * 86400)
    #expect(!trial.isExpired(asOf: sevenDaysIn))
    #expect(trial.daysRemaining(asOf: sevenDaysIn) == 7)
}

@Test func trialOnItsLastPartialDayRoundsUpToOneDayRemaining() {
    let trial = TrialState.days(14, from: reference)
    let thirteenAndAHalfDaysIn = reference.addingTimeInterval(13.5 * 86400)
    #expect(!trial.isExpired(asOf: thirteenAndAHalfDaysIn))
    #expect(trial.daysRemaining(asOf: thirteenAndAHalfDaysIn) == 1)
}

@Test func trialOneSecondBeforeItsEndIsStillActive() {
    let trial = TrialState.days(14, from: reference)
    let almostOver = trial.endsAt.addingTimeInterval(-1)
    #expect(!trial.isExpired(asOf: almostOver))
    #expect(trial.daysRemaining(asOf: almostOver) == 1)
}

@Test func trialIsExpiredExactlyAtItsEndInstant() {
    let trial = TrialState.days(14, from: reference)
    #expect(trial.isExpired(asOf: trial.endsAt))
    #expect(trial.daysRemaining(asOf: trial.endsAt) == 0)
}

@Test func trialOneSecondAfterItsEndIsExpired() {
    let trial = TrialState.days(14, from: reference)
    let justAfter = trial.endsAt.addingTimeInterval(1)
    #expect(trial.isExpired(asOf: justAfter))
    #expect(trial.daysRemaining(asOf: justAfter) == 0)
}

@Test func trialLongAfterItsEndIsExpiredNotNegative() {
    let trial = TrialState.days(14, from: reference)
    let wayLater = reference.addingTimeInterval(400 * 86400)
    #expect(trial.isExpired(asOf: wayLater))
    #expect(trial.daysRemaining(asOf: wayLater) == 0)
}

@Test func trialWithAClockRolledBackwardIsTreatedAsFreshRatherThanNegative() {
    // A user setting their system clock backward, deliberately or not, must never see the
    // trial read as expired or produce a nonsensical days-remaining value.
    let trial = TrialState.days(14, from: reference)
    let beforeItStarted = reference.addingTimeInterval(-100_000)
    #expect(!trial.isExpired(asOf: beforeItStarted))
    #expect(trial.daysRemaining(asOf: beforeItStarted) == 14)
}

@Test func zeroLengthTrialIsImmediatelyExpired() {
    let trial = TrialState(startedAt: reference, duration: 0)
    #expect(trial.isExpired(asOf: reference))
    #expect(trial.daysRemaining(asOf: reference) == 0)
}

// MARK: - LicenseState

@Test func purchasedIsFullAccessWithNoTrialAtAll() {
    let license = LicenseState(isPurchased: true, trial: nil)
    #expect(license.hasFullAccess(asOf: reference))
    #expect(license.status(asOf: reference) == .purchased)
}

@Test func purchasedOverridesAnExpiredTrial() {
    let expiredTrial = TrialState.days(14, from: reference.addingTimeInterval(-30 * 86400))
    let license = LicenseState(isPurchased: true, trial: expiredTrial)
    #expect(license.hasFullAccess(asOf: reference))
    #expect(license.status(asOf: reference) == .purchased)
}

@Test func unpurchasedWithNoTrialHasNoFullAccess() {
    let license = LicenseState.unpurchasedNoTrial
    #expect(!license.hasFullAccess(asOf: reference))
    #expect(license.status(asOf: reference) == .noTrialNoPurchase)
}

@Test func unpurchasedWithAnActiveTrialHasFullAccess() {
    let license = LicenseState(isPurchased: false, trial: TrialState.days(14, from: reference))
    let midTrial = reference.addingTimeInterval(3 * 86400)
    #expect(license.hasFullAccess(asOf: midTrial))
    #expect(license.status(asOf: midTrial) == .trialActive(daysRemaining: 11))
}

@Test func unpurchasedWithAnExpiredTrialHasNoFullAccess() {
    let trial = TrialState.days(14, from: reference)
    let license = LicenseState(isPurchased: false, trial: trial)
    let afterExpiry = trial.endsAt.addingTimeInterval(1)
    #expect(!license.hasFullAccess(asOf: afterExpiry))
    #expect(license.status(asOf: afterExpiry) == .trialExpired)
}

@Test func statusTransitionsExactlyAtTheTrialBoundary() {
    let trial = TrialState.days(14, from: reference)
    let license = LicenseState(isPurchased: false, trial: trial)

    let oneSecondBefore = trial.endsAt.addingTimeInterval(-1)
    guard case .trialActive(let days) = license.status(asOf: oneSecondBefore) else {
        Issue.record("expected trialActive one second before the boundary")
        return
    }
    #expect(days == 1)

    #expect(license.status(asOf: trial.endsAt) == .trialExpired)
}

// MARK: - FeatureGate

@Test func aFreeTierFeatureIsUnlockedRegardlessOfLicense() {
    #expect(FeatureGate.isUnlocked(isFreeTier: true, license: .unpurchasedNoTrial, asOf: reference))

    let expiredTrialLicense = LicenseState(isPurchased: false, trial: TrialState.days(0, from: reference))
    #expect(FeatureGate.isUnlocked(isFreeTier: true, license: expiredTrialLicense, asOf: reference))
}

@Test func aPaidFeatureIsLockedWithoutPurchaseOrTrial() {
    #expect(!FeatureGate.isUnlocked(isFreeTier: false, license: .unpurchasedNoTrial, asOf: reference))
}

@Test func aPaidFeatureIsUnlockedByPurchase() {
    let license = LicenseState(isPurchased: true, trial: nil)
    #expect(FeatureGate.isUnlocked(isFreeTier: false, license: license, asOf: reference))
}

@Test func aPaidFeatureIsUnlockedByAnActiveTrialAndLockedOnceItExpires() {
    let trial = TrialState.days(14, from: reference)
    let license = LicenseState(isPurchased: false, trial: trial)

    #expect(FeatureGate.isUnlocked(isFreeTier: false, license: license, asOf: reference))
    #expect(!FeatureGate.isUnlocked(isFreeTier: false, license: license, asOf: trial.endsAt))
}
