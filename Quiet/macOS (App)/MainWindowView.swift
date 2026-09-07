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

    var body: some View {
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

            BlockingView(model: blockingModel)
                .tabItem { Label("Block", systemImage: "hand.raised") }
        }
        .frame(minWidth: 520, minHeight: 460)
    }
}
