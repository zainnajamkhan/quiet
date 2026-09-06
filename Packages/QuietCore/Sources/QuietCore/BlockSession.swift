//
//  BlockSession.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// A running app-blocking session on the Mac companion app. Strict mode is the whole
/// selling point against a plain toggle: once started, it must not be cancellable by
/// quitting the app, deleting it, or restarting the Mac. This type only decides whether
/// cancellation is currently allowed; actually surviving a reboot is a persistence
/// concern for the app target, not something this pure type can enforce by itself.
public struct BlockSession: Equatable, Sendable {
    public let startedAt: Date
    public let duration: TimeInterval
    public let isStrict: Bool

    public init(startedAt: Date, duration: TimeInterval, isStrict: Bool) {
        self.startedAt = startedAt
        self.duration = duration
        self.isStrict = isStrict
    }

    public var endsAt: Date {
        startedAt.addingTimeInterval(duration)
    }

    /// True from the moment the session starts up to, but not including, `endsAt`. A
    /// clock rolled backward before `startedAt` reads as not yet active rather than
    /// active for some enormous, wrapped duration.
    public func isActive(asOf now: Date) -> Bool {
        now >= startedAt && now < endsAt
    }

    public func remaining(asOf now: Date) -> TimeInterval {
        guard isActive(asOf: now) else { return 0 }
        return endsAt.timeIntervalSince(now)
    }

    /// A non strict session can always be cancelled. A strict session can only be
    /// cancelled once it has naturally ended; while it is running, this is false and the
    /// app must refuse to offer a way out, which is the entire point of strict mode.
    public func canCancel(asOf now: Date) -> Bool {
        !isStrict || !isActive(asOf: now)
    }
}
