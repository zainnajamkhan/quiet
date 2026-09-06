//
//  ScheduleEvaluator.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

public enum ScheduleEvaluator {

    public static let focusWildcard = "*"

    /// The day, in the 1..7 (Sunday..Saturday) numbering, immediately before `weekday`.
    static func previousWeekday(_ weekday: Int) -> Int {
        ((weekday - 2 + 7) % 7) + 1
    }

    static func windowIsActive(_ window: ScheduleWindow, at moment: ScheduleMoment) -> Bool {
        guard let start = ScheduleValidator.minutes(from: window.start),
              let end = ScheduleValidator.minutes(from: window.end),
              start != end
        else { return false }

        let today = window.days.contains(moment.weekday)
        let yesterday = window.days.contains(previousWeekday(moment.weekday))

        if start < end {
            return today && moment.minutesSinceMidnight >= start && moment.minutesSinceMidnight < end
        }

        let lateNightPortion = today && moment.minutesSinceMidnight >= start
        let earlyMorningPortion = yesterday && moment.minutesSinceMidnight < end
        return lateNightPortion || earlyMorningPortion
    }

    public static func isActive(
        _ schedule: Schedule,
        at moment: ScheduleMoment,
        activeFocusIdentifiers: [String] = []
    ) -> Bool {
        guard ScheduleValidator.isValid(schedule) else { return false }
        guard schedule.enabled else { return false }
        guard moment.isWellFormed else { return false }

        switch schedule.kind {
        case .always:
            return true

        case .window:
            guard let windows = schedule.windows else { return false }
            return windows.contains { windowIsActive($0, at: moment) }

        case .focus:
            guard let identifiers = schedule.focusIdentifiers else { return false }
            if identifiers.contains(focusWildcard) { return !activeFocusIdentifiers.isEmpty }
            return identifiers.contains { activeFocusIdentifiers.contains($0) }
        }
    }
}
