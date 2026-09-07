//
//  FocusStateStore.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// Persists which Focus is currently driving Quiet, in the App Group container so that
/// whichever process the Focus Filter intent happens to run in can hand the answer to the
/// app and the Safari extension.
///
/// Background, because the shape of this is dictated by a platform limitation rather than
/// by preference: there is no macOS API to ask which named Focus is active. The public
/// route is `SetFocusFilterIntent`, which is push based, so Quiet keeps its own record of
/// the answer and updates it when the system calls the intent. The private alternative,
/// parsing `~/Library/DoNotDisturb/DB/Assertions.json`, is undocumented, already broke on
/// macOS 26, and is unavailable under the sandbox, so it is deliberately not used.
public enum FocusStateStore {

    public static func fileURL() -> URL {
        SharedStateStore.fileURL().deletingLastPathComponent().appendingPathComponent("focus-state.json")
    }

    public static func load(from url: URL = fileURL()) -> FocusState {
        guard let data = try? Data(contentsOf: url) else { return .none }
        return (try? JSONDecoder().decode(FocusState.self, from: data)) ?? .none
    }

    public static func save(_ state: FocusState, to url: URL = fileURL()) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }

    /// Records the Focus link the system just applied. Replaces rather than appends: macOS
    /// runs one Focus at a time, so two identifiers being active at once would mean Quiet
    /// had missed a deactivation, and carrying that forward would keep blocking after the
    /// Focus ended.
    @discardableResult
    public static func activate(_ identifier: String, now: Date = Date(), to url: URL = fileURL()) -> FocusState {
        let state = FocusState(activeIdentifiers: [identifier], updatedAt: now)
        try? save(state, to: url)
        return state
    }

    @discardableResult
    public static func clear(now: Date = Date(), to url: URL = fileURL()) -> FocusState {
        let state = FocusState(activeIdentifiers: [], updatedAt: now)
        try? save(state, to: url)
        return state
    }
}
