//
//  ExtensionStatusModel.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Combine
import SafariServices
import AppKit

/// Tracks whether the Safari extension is switched on. This is the single biggest drop off
/// point for a Safari extension app: the extension ships disabled, Safari gives no prompt,
/// and a user who does not know to go and enable it concludes the app is broken.
@MainActor
final class ExtensionStatusModel: ObservableObject {

    enum State: Equatable {
        case unknown
        case enabled
        case disabled
        case failed(String)
    }

    static let extensionBundleIdentifier = "com.app.Quiet.Extension"

    @Published private(set) var state: State = .unknown

    var isEnabled: Bool { state == .enabled }

    func refresh() {
        SFSafariExtensionManager.getStateOfSafariExtension(
            withIdentifier: Self.extensionBundleIdentifier
        ) { [weak self] extensionState, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.state = .failed(error.localizedDescription)
                } else if let extensionState {
                    self.state = extensionState.isEnabled ? .enabled : .disabled
                } else {
                    self.state = .unknown
                }
            }
        }
    }

    /// Opens Safari directly on this extension's row in Settings. Notably this does NOT
    /// quit the app, unlike the template's version: quitting made it look as though
    /// nothing had happened and left the user with no way back to the instructions.
    func openSafariSettings() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: Self.extensionBundleIdentifier
        ) { [weak self] _ in
            Task { @MainActor in
                // Safari takes a moment to apply a change made in its settings pane.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.refresh()
            }
        }
    }
}
