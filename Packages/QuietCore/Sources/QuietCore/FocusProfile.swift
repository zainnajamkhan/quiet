//
//  FocusProfile.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// A Focus the user has linked to Quiet.
///
/// macOS never tells an app which Focus is running (see FocusStateStore for the research
/// behind that), so the link is made by the user twice: they name it here, then pick that
/// name in System Settings when adding Quiet as a Focus Filter. The `id` is what travels
/// through `Schedule.focusIdentifiers`; the `name` exists only to be recognisable in the
/// System Settings picker.
public struct FocusProfile: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum FocusPolicy {

    /// Matches whichever Focus is running rather than one specific Focus. Shares the
    /// wildcard the schedule engine already understands, so "any Focus" needs no special
    /// case in evaluation: it is an ordinary identifier that happens to be "*".
    public static let anyFocusIdentifier = ScheduleEvaluator.focusWildcard

    /// Always offered in the System Settings picker so the common case, "block whenever
    /// any Focus is on", works without the user naming anything in Quiet first.
    public static let anyFocus = FocusProfile(id: anyFocusIdentifier, name: "Any Focus")

    private static let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789")

    /// Turns a display name into a stable identifier. Deliberately lossy and deterministic:
    /// "Work Mode", "work mode" and "  Work   Mode  " are the same Focus to a person, so
    /// they must be the same identifier here too.
    public static func slug(from name: String) -> String? {
        var pieces: [String] = []
        var current = ""
        for character in name.lowercased() {
            if allowed.contains(character) {
                current.append(character)
            } else if !current.isEmpty {
                pieces.append(current)
                current = ""
            }
        }
        if !current.isEmpty { pieces.append(current) }

        let slug = pieces.joined(separator: "-")
        return slug.isEmpty ? nil : slug
    }

    /// Builds a profile whose identifier does not collide with one already in use. Names
    /// are allowed to repeat (the user may genuinely want two similarly named links) but
    /// identifiers may not, because a collision would silently merge two Focus links into
    /// one and make removing either of them disable both.
    public static func makeProfile(name rawName: String, existing: [FocusProfile]) -> FocusProfile? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        // `slug` only ever emits a-z, 0-9 and "-", so a user supplied name can never
        // collide with the "*" wildcard and no separate guard for it is needed.
        guard let base = slug(from: name) else { return nil }

        let taken = Set(existing.map(\.id))
        if !taken.contains(base) {
            return FocusProfile(id: base, name: name)
        }
        for suffix in 2...99 {
            let candidate = "\(base)-\(suffix)"
            if !taken.contains(candidate) {
                return FocusProfile(id: candidate, name: name)
            }
        }
        return nil
    }

    /// Schedule identifiers are validated against `[a-z0-9]+(-[a-z0-9]+)*`, so this cannot
    /// simply interpolate the profile id: the wildcard profile's id is "*", which is not a
    /// legal identifier. The wildcard becomes a bare "focus", which no named profile can
    /// ever produce because that would require an empty profile id.
    public static func scheduleIdentifier(for profileID: String) -> String {
        profileID == anyFocusIdentifier ? "focus" : "focus-\(profileID)"
    }

    /// The schedules that make "block while this Focus is on" true. Derived rather than
    /// stored so the profile list stays the single source of truth: adding or removing a
    /// profile cannot leave a stale schedule behind that keeps blocking forever.
    public static func schedules(for profiles: [FocusProfile]) -> [Schedule] {
        profiles.map { profile in
            Schedule(
                id: scheduleIdentifier(for: profile.id),
                kind: .focus,
                enabled: true,
                focusIdentifiers: [profile.id]
            )
        }
    }
}
