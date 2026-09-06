//
//  FrictionModeTests.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

private struct FrictionVectorFile: Decodable {
    let delayCases: [DelayVector]
    let reasonCases: [ReasonVector]
}

private struct DelayVector: Decodable {
    let description: String
    let startedAt: TimeInterval
    let delaySeconds: TimeInterval
    let now: TimeInterval
    let expected: Bool
}

private struct ReasonVector: Decodable {
    let description: String
    let reason: String
    let expected: Bool
}

private enum FrictionFixtures {
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func vectors() throws -> FrictionVectorFile {
        let url = repositoryRoot
            .appendingPathComponent("Rules")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("friction-vectors.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FrictionVectorFile.self, from: data)
    }
}

@Test func everySharedDelayVectorEvaluatesAsExpected() throws {
    for vector in try FrictionFixtures.vectors().delayCases {
        let got = FrictionMode.isDelayComplete(startedAt: vector.startedAt, delaySeconds: vector.delaySeconds, now: vector.now)
        #expect(got == vector.expected, Comment(rawValue: vector.description))
    }
}

@Test func everySharedReasonVectorEvaluatesAsExpected() throws {
    for vector in try FrictionFixtures.vectors().reasonCases {
        #expect(FrictionMode.isReasonValid(vector.reason) == vector.expected, Comment(rawValue: vector.description))
    }
}

@Test func reasonValidityHonoursACustomMinimumLength() {
    #expect(FrictionMode.isReasonValid("ab", minimumLength: 2))
    #expect(!FrictionMode.isReasonValid("a", minimumLength: 2))
    #expect(FrictionMode.isReasonValid("", minimumLength: 0))
}

@Test func defaultMinimumReasonLengthIsTheDocumentedValue() {
    #expect(FrictionMode.defaultMinimumReasonLength == 3)
}
