//
//  SharedStateStore.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// Reads and writes SharedState to a plain file, readable by both the container app and
/// the extension's native handler since neither currently has App Sandbox turned on.
///
/// This is a deliberate, temporary shortcut: Mac App Store submission requires sandboxing,
/// at which point this must move to an App Group shared container instead (a sandboxed
/// process cannot read an arbitrary path like this one). Tracked as an open item in
/// mac-apps/01-quiet.md. Do not build anything else on top of the exact file path; go
/// through this type so the migration is a one file change.
public enum SharedStateStore {

    public static func fileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Quiet", isDirectory: true).appendingPathComponent("shared-state.json")
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
