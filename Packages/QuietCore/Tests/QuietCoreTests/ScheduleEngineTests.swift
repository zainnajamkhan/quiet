//
//  ScheduleEngineTests.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

private struct ScheduleVectorFile: Decodable {
    let cases: [ScheduleVector]
}

private struct ScheduleVector: Decodable {
    let description: String
    let schedule: Schedule
    let moment: ScheduleMoment
    let activeFocusIdentifiers: [String]
    let expected: Bool
}

private enum ScheduleFixtures {

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func vectors() throws -> [ScheduleVector] {
        let url = repositoryRoot
            .appendingPathComponent("Rules")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("schedule-vectors.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ScheduleVectorFile.self, from: data).cases
    }
}

// MARK: - Shared reference vectors

@Test func scheduleVectorFileIsNonEmpty() throws {
    #expect(try ScheduleFixtures.vectors().count > 0)
}

@Test func everySharedReferenceVectorEvaluatesAsExpected() throws {
    for vector in try ScheduleFixtures.vectors() {
        let got = ScheduleEvaluator.isActive(
            vector.schedule,
            at: vector.moment,
            activeFocusIdentifiers: vector.activeFocusIdentifiers
        )
        #expect(got == vector.expected, Comment(rawValue: vector.description))
    }
}

// MARK: - Validation

@Test func validationAcceptsAWellFormedAlwaysSchedule() {
    #expect(ScheduleValidator.validate(Schedule(id: "s", kind: .always, enabled: true)).isEmpty)
}

@Test func validationAcceptsAWellFormedWindowSchedule() {
    let schedule = Schedule(
        id: "s",
        kind: .window,
        enabled: true,
        windows: [ScheduleWindow(days: [2, 3], start: "09:00", end: "17:00")]
    )
    #expect(ScheduleValidator.validate(schedule).isEmpty)
}

@Test func validationAcceptsAWellFormedFocusSchedule() {
    let schedule = Schedule(id: "s", kind: .focus, enabled: true, focusIdentifiers: ["com.apple.focus.work"])
    #expect(ScheduleValidator.validate(schedule).isEmpty)
}

@Test func validationRejectsAMalformedIdentifier() {
    let schedule = Schedule(id: "Bad Id", kind: .always, enabled: true)
    #expect(ScheduleValidator.validate(schedule).contains { $0.contains("id") })
}

@Test func validationRejectsAWindowScheduleWithNoWindows() {
    let schedule = Schedule(id: "s", kind: .window, enabled: true, windows: [])
    #expect(ScheduleValidator.validate(schedule).contains { $0.contains("windows") })
}

@Test func validationRejectsOutOfRangeOrDuplicateDays() {
    let outOfRange = Schedule(
        id: "s", kind: .window, enabled: true,
        windows: [ScheduleWindow(days: [0, 8], start: "09:00", end: "17:00")]
    )
    #expect(ScheduleValidator.validate(outOfRange).contains { $0.contains("outside 1..7") })

    let duplicate = Schedule(
        id: "s", kind: .window, enabled: true,
        windows: [ScheduleWindow(days: [2, 2], start: "09:00", end: "17:00")]
    )
    #expect(ScheduleValidator.validate(duplicate).contains { $0.contains("duplicate") })
}

@Test func validationRejectsMalformedTimesAndEqualStartEnd() {
    let badStart = Schedule(id: "s", kind: .window, enabled: true, windows: [ScheduleWindow(days: [2], start: "9:00", end: "17:00")])
    #expect(ScheduleValidator.validate(badStart).contains { $0.contains(".start") })

    let badEnd = Schedule(id: "s", kind: .window, enabled: true, windows: [ScheduleWindow(days: [2], start: "09:00", end: "24:00")])
    #expect(ScheduleValidator.validate(badEnd).contains { $0.contains(".end") })

    let equal = Schedule(id: "s", kind: .window, enabled: true, windows: [ScheduleWindow(days: [2], start: "09:00", end: "09:00")])
    #expect(ScheduleValidator.validate(equal).contains { $0.contains("must not be equal") })
}

@Test func validationRejectsAFocusScheduleWithNoIdentifiers() {
    let schedule = Schedule(id: "s", kind: .focus, enabled: true, focusIdentifiers: [])
    #expect(ScheduleValidator.validate(schedule).contains { $0.contains("focusIdentifiers") })
}

// MARK: - Evaluation edge cases beyond the shared vectors

@Test func evaluationRejectsAMalformedMoment() {
    let schedule = Schedule(id: "s", kind: .always, enabled: true)
    #expect(!ScheduleEvaluator.isActive(schedule, at: ScheduleMoment(weekday: 8, minutesSinceMidnight: 0)))
    #expect(!ScheduleEvaluator.isActive(schedule, at: ScheduleMoment(weekday: 1, minutesSinceMidnight: 1440)))
    #expect(!ScheduleEvaluator.isActive(schedule, at: ScheduleMoment(weekday: 1, minutesSinceMidnight: -1)))
}

@Test func evaluationOfAnInvalidScheduleIsFalseRatherThanTrapping() {
    let invalid = Schedule(id: "not valid", kind: .window, enabled: true, windows: [])
    #expect(!ScheduleEvaluator.isActive(invalid, at: ScheduleMoment(weekday: 3, minutesSinceMidnight: 600)))
}

@Test func evaluationDefaultsToNoActiveFocusIdentifiers() {
    let schedule = Schedule(id: "s", kind: .focus, enabled: true, focusIdentifiers: ["com.apple.focus.work"])
    #expect(!ScheduleEvaluator.isActive(schedule, at: ScheduleMoment(weekday: 2, minutesSinceMidnight: 600)))
}

@Test func momentNowExtractsWeekdayAndMinutesInAFixedCalendar() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    var components = DateComponents()
    components.year = 2026
    components.month = 9
    components.day = 9 // a Wednesday
    components.hour = 9
    components.minute = 5
    let date = calendar.date(from: components)!

    let moment = ScheduleMoment.now(calendar: calendar, date: date)
    #expect(moment.weekday == 4)
    #expect(moment.minutesSinceMidnight == 545)
}
