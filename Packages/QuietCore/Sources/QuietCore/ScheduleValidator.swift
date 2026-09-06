//
//  ScheduleValidator.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

public enum ScheduleValidator {

    private static let timePattern = try! NSRegularExpression(pattern: "^([01][0-9]|2[0-3]):([0-5][0-9])$")

    public static func minutes(from time: String) -> Int? {
        let range = NSRange(time.startIndex..<time.endIndex, in: time)
        guard let match = timePattern.firstMatch(in: time, options: [], range: range),
              let hourRange = Range(match.range(at: 1), in: time),
              let minuteRange = Range(match.range(at: 2), in: time),
              let hour = Int(time[hourRange]),
              let minute = Int(time[minuteRange])
        else { return nil }
        return hour * 60 + minute
    }

    public static func isValidIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty else { return false }
        let segments = identifier.split(separator: "-", omittingEmptySubsequences: false)
        return segments.allSatisfy { segment in
            !segment.isEmpty && segment.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) }
        }
    }

    public static func validate(_ schedule: Schedule) -> [String] {
        var errors: [String] = []

        if !isValidIdentifier(schedule.id) {
            errors.append("id is missing or malformed")
        }

        switch schedule.kind {
        case .always:
            break

        case .window:
            guard let windows = schedule.windows, !windows.isEmpty else {
                errors.append("windows is required and must be a non empty array for kind window")
                break
            }
            for (index, window) in windows.enumerated() {
                let at = "windows[\(index)]"
                if window.days.isEmpty {
                    errors.append("\(at).days is not a non empty array")
                } else {
                    if !window.days.allSatisfy({ (1...7).contains($0) }) {
                        errors.append("\(at).days contains a value outside 1..7")
                    }
                    if Set(window.days).count != window.days.count {
                        errors.append("\(at).days contains a duplicate")
                    }
                }
                let start = minutes(from: window.start)
                let end = minutes(from: window.end)
                if start == nil { errors.append("\(at).start is not a HH:MM time: \(window.start)") }
                if end == nil { errors.append("\(at).end is not a HH:MM time: \(window.end)") }
                if let start, let end, start == end {
                    errors.append("\(at).start and .end must not be equal")
                }
            }

        case .focus:
            guard let identifiers = schedule.focusIdentifiers, !identifiers.isEmpty else {
                errors.append("focusIdentifiers is required and must be a non empty array for kind focus")
                break
            }
            for (index, identifier) in identifiers.enumerated() where identifier.isEmpty {
                errors.append("focusIdentifiers[\(index)] is not a non empty string")
            }
        }

        return errors
    }

    public static func isValid(_ schedule: Schedule) -> Bool {
        validate(schedule).isEmpty
    }
}
