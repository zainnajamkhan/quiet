//
//  Schedule.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// A moment in the user's local wall clock, already extracted from a `Date`. Kept separate
/// from `Date` so the evaluation logic in `ScheduleEvaluator` never touches a timezone: the
/// impure extraction happens once, in `ScheduleMoment.now(calendar:)`, and everything after
/// that point is deterministic and shared with the JavaScript engine's test vectors.
public struct ScheduleMoment: Codable, Equatable, Sendable {
    /// 1 = Sunday .. 7 = Saturday, matching `Calendar`'s default weekday numbering.
    public let weekday: Int
    public let minutesSinceMidnight: Int

    public init(weekday: Int, minutesSinceMidnight: Int) {
        self.weekday = weekday
        self.minutesSinceMidnight = minutesSinceMidnight
    }

    public static func now(calendar: Calendar = .current, date: Date = Date()) -> ScheduleMoment {
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let weekday = components.weekday ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return ScheduleMoment(weekday: weekday, minutesSinceMidnight: hour * 60 + minute)
    }

    var isWellFormed: Bool {
        (1...7).contains(weekday) && (0..<1440).contains(minutesSinceMidnight)
    }
}

public struct ScheduleWindow: Codable, Equatable, Sendable {
    public let days: [Int]
    public let start: String
    public let end: String

    public init(days: [Int], start: String, end: String) {
        self.days = days
        self.start = start
        self.end = end
    }
}

public struct Schedule: Codable, Equatable, Sendable, Identifiable {

    public enum Kind: String, Codable, Equatable, Sendable {
        case always
        case window
        case focus
    }

    public let id: String
    public let kind: Kind
    public let enabled: Bool
    public let windows: [ScheduleWindow]?
    public let focusIdentifiers: [String]?

    public init(id: String, kind: Kind, enabled: Bool, windows: [ScheduleWindow]? = nil, focusIdentifiers: [String]? = nil) {
        self.id = id
        self.kind = kind
        self.enabled = enabled
        self.windows = windows
        self.focusIdentifiers = focusIdentifiers
    }
}
