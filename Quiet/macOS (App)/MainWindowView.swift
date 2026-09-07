//
//  MainWindowView.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import SwiftUI
import QuietCore

/// One window with two tabs, replacing the two separate windows the app used to open on
/// launch (the template's extension status screen and a bare rules list), which competed
/// for attention and left it unclear which one was "the app".
struct MainWindowView: View {

    let ruleEditor: RuleEditorView?
    @ObservedObject var blockingModel: BlockingModel
    @ObservedObject var purchases: PurchaseModel
    @ObservedObject var extensionStatus: ExtensionStatusModel
    @ObservedObject var focus: FocusMonitor

    var body: some View {
        VStack(spacing: 0) {
            if extensionStatus.state == .disabled {
                HStack(spacing: 10) {
                    Label(
                        "The Quiet extension is switched off in Safari, so nothing is being hidden.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    .font(.callout)
                    Spacer()
                    Button("Open Safari Settings…") { extensionStatus.openSafariSettings() }
                }
                .padding(10)
                .background(.orange.opacity(0.12))
            }

            tabs
        }
        .onAppear { extensionStatus.refresh() }
    }

    private var tabs: some View {
        TabView {
            Group {
                if let ruleEditor {
                    ruleEditor
                } else {
                    ContentUnavailableView(
                        "Could not load rules",
                        systemImage: "exclamationmark.triangle",
                        description: Text("ruleset.json is missing from the app bundle or could not be parsed.")
                    )
                }
            }
            .tabItem { Label("Hide", systemImage: "eye.slash") }

            BlockingView(model: blockingModel, purchases: purchases, focus: focus)
                .tabItem { Label("Block", systemImage: "hand.raised") }
        }
        // NSHostingView sizes the window from this frame, not from the window's own
        // contentRect, so the opening size is set here. Ideal rather than minimum: the
        // Block tab wants the height, but forcing it as a floor would make the window
        // unshrinkable on a small display.
        .frame(minWidth: 520, idealWidth: 560, minHeight: 440, idealHeight: 660)
    }
}
