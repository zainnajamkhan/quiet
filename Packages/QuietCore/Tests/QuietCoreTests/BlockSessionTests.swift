//
//  BlockSessionTests.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

private let reference = Date(timeIntervalSince1970: 1_800_000_000)

@Test func sessionIsActiveAtItsOwnStartInstant() {
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)
    #expect(session.isActive(asOf: reference))
    #expect(session.remaining(asOf: reference) == 3600)
}

@Test func sessionIsActiveMidway() {
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)
    let midpoint = reference.addingTimeInterval(1800)
    #expect(session.isActive(asOf: midpoint))
    #expect(session.remaining(asOf: midpoint) == 1800)
}

@Test func sessionIsInactiveExactlyAtItsEndInstant() {
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)
    #expect(!session.isActive(asOf: session.endsAt))
    #expect(session.remaining(asOf: session.endsAt) == 0)
}

@Test func sessionIsActiveOneSecondBeforeItsEnd() {
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)
    let almostOver = session.endsAt.addingTimeInterval(-1)
    #expect(session.isActive(asOf: almostOver))
    #expect(session.remaining(asOf: almostOver) == 1)
}

@Test func sessionIsInactiveOneSecondAfterItsEnd() {
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)
    let justAfter = session.endsAt.addingTimeInterval(1)
    #expect(!session.isActive(asOf: justAfter))
    #expect(session.remaining(asOf: justAfter) == 0)
}

@Test func sessionBeforeItsStartIsNotYetActive() {
    // Guards against a clock rolled backward reading as an active session of some huge,
    // wrapped duration rather than simply "not started yet".
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)
    let beforeStart = reference.addingTimeInterval(-10)
    #expect(!session.isActive(asOf: beforeStart))
    #expect(session.remaining(asOf: beforeStart) == 0)
}

@Test func zeroDurationSessionIsNeverActive() {
    let session = BlockSession(startedAt: reference, duration: 0, isStrict: false)
    #expect(!session.isActive(asOf: reference))
}

@Test func nonStrictSessionCanAlwaysBeCancelled() {
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)
    #expect(session.canCancel(asOf: reference))
    #expect(session.canCancel(asOf: reference.addingTimeInterval(1800)))
    #expect(session.canCancel(asOf: session.endsAt))
}

@Test func strictSessionCannotBeCancelledWhileActive() {
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: true)
    #expect(!session.canCancel(asOf: reference))
    #expect(!session.canCancel(asOf: reference.addingTimeInterval(1800)))
    #expect(!session.canCancel(asOf: session.endsAt.addingTimeInterval(-1)))
}

@Test func strictSessionCanBeCancelledOnceItHasNaturallyEnded() {
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: true)
    #expect(session.canCancel(asOf: session.endsAt))
    #expect(session.canCancel(asOf: session.endsAt.addingTimeInterval(100)))
}

@Test func strictSessionBeforeItStartsCanBeCancelled() {
    // Not yet active, so there is nothing strict to enforce yet.
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: true)
    #expect(session.canCancel(asOf: reference.addingTimeInterval(-10)))
}
