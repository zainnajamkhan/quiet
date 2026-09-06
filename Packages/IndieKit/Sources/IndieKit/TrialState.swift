//
//  TrialState.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// A time limited trial, evaluated against a supplied `now` rather than reading the clock
/// itself, so every rule here is a pure function and every edge case is a unit test rather
/// than something discovered from a support email in month two.
public struct TrialState: Equatable, Sendable {
    public let startedAt: Date
    public let duration: TimeInterval

    public init(startedAt: Date, duration: TimeInterval) {
        self.startedAt = startedAt
        self.duration = duration
    }

    public static func days(_ days: Int, from startedAt: Date) -> TrialState {
        TrialState(startedAt: startedAt, duration: TimeInterval(days) * 86400)
    }

    public var endsAt: Date {
        startedAt.addingTimeInterval(duration)
    }

    /// Time elapsed since the trial started. A clock set backward (accidentally or to try to
    /// extend the trial) never produces a negative value here: it resets the trial to appear
    /// freshly started rather than crediting negative elapsed time, which is the safe
    /// direction for both correctness and for not rewarding tampering.
    public func elapsed(asOf now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(startedAt))
    }

    /// True from the instant `endsAt` is reached, inclusive.
    public func isExpired(asOf now: Date) -> Bool {
        elapsed(asOf: now) >= duration
    }

    /// Whole days remaining, rounded up, so the last partial day still reads as "1 day left"
    /// rather than "0 days left" while the trial is still technically active.
    public func daysRemaining(asOf now: Date) -> Int {
        guard duration > 0 else { return 0 }
        let remaining = duration - elapsed(asOf: now)
        guard remaining > 0 else { return 0 }
        return Int((remaining / 86400).rounded(.up))
    }
}
