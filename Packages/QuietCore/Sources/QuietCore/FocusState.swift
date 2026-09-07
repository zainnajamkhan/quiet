//
//  FocusState.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// Which Focus links are currently driving Quiet.
///
/// A list rather than a single value because `ScheduleEvaluator` already takes a list, and
/// because a "clear" and a "set" can arrive in either order when one Focus replaces
/// another. `updatedAt` exists so a later reconciliation can tell a fresh answer from one
/// written before the app was last quit.
public struct FocusState: Codable, Equatable, Sendable {
    public let activeIdentifiers: [String]
    public let updatedAt: Date

    public init(activeIdentifiers: [String] = [], updatedAt: Date = .distantPast) {
        self.activeIdentifiers = activeIdentifiers
        self.updatedAt = updatedAt
    }

    public static let none = FocusState()

    public var isActive: Bool { !activeIdentifiers.isEmpty }
}
