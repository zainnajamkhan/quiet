//
//  SharedStateStore.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// Reads and writes SharedState to a location both the container app and the Safari
/// extension can reach.
///
/// Both processes are sandboxed (Xcode injects `com.apple.security.app-sandbox` for a
/// macOS app and its app extension even when no entitlements file is set), and each gets
/// its own isolated container, so a plain path under Application Support resolves to two
/// different files that can never see each other. The App Group container is the only
/// shared writable location available to both.
public enum SharedStateStore {

    /// App Group identifiers follow different conventions per platform: macOS requires the
    /// team identifier as a prefix, iOS does not. Getting this wrong yields a nil container
    /// and silently unshared state, which is exactly the bug this type exists to prevent.
    public static let appGroupIdentifier: String = {
        #if os(macOS)
        return "CU82DCKHTL.group.com.app.Quiet"
        #else
        return "group.com.app.Quiet"
        #endif
    }()

    /// Falls back to the per process Application Support directory if the App Group
    /// container is unavailable. That fallback is deliberately non fatal but it does mean
    /// the app and extension stop sharing state, so `isUsingAppGroup` exists to make the
    /// degraded case visible rather than silent.
    public static func fileURL() -> URL {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            return container.appendingPathComponent("shared-state.json")
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Quiet", isDirectory: true).appendingPathComponent("shared-state.json")
    }

    public static var isUsingAppGroup: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil
    }

    /// Human readable description of where state is actually being stored, for surfacing
    /// in the UI. If this reports the fallback, the app and the extension are writing to
    /// separate sandbox containers and toggles will appear to do nothing.
    public static var storageDescription: String {
        isUsingAppGroup
            ? "Shared via App Group (app and extension can see each other)"
            : "NOT SHARED: App Group unavailable, so the extension cannot see these settings"
    }

    public static func load(from url: URL = fileURL()) -> SharedState {
        guard let data = try? Data(contentsOf: url) else { return .empty }
        return (try? JSONDecoder().decode(SharedState.self, from: data)) ?? .empty
    }

    public static func save(_ state: SharedState, to url: URL = fileURL()) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
    }
}
