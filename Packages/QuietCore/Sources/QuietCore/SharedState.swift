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

    /// Hosts the extension should refuse right now, already resolved against schedules and
    /// any running session by the native app. Deliberately a flat list: the extension has
    /// no clock of its own to trust and no reason to reimplement schedule evaluation.
    public let blockedHosts: [String]

    public init(preferences: [String: Bool] = [:], blockedHosts: [String] = []) {
        self.preferences = preferences
        self.blockedHosts = blockedHosts
    }

    public static let empty = SharedState()

    private enum CodingKeys: String, CodingKey {
        case preferences
        case blockedHosts
    }

    /// Decodes older files written before blockedHosts existed, so an app update never
    /// starts by throwing away the user's settings.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferences = try container.decodeIfPresent([String: Bool].self, forKey: .preferences) ?? [:]
        blockedHosts = try container.decodeIfPresent([String].self, forKey: .blockedHosts) ?? []
    }
}
