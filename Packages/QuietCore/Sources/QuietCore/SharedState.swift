//
//  SharedState.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// What the native app hands to the extension: per-feature on/off overrides. Absent keys
/// fall back to each feature's own default, exactly as `FeatureResolution.isEnabled`
/// already expects, so the extension side needs no new merge logic beyond "prefer this
/// over the locally stored copy when present."
public struct SharedState: Codable, Equatable, Sendable {
    public let preferences: [String: Bool]

    public init(preferences: [String: Bool] = [:]) {
        self.preferences = preferences
    }

    public static let empty = SharedState()
}
