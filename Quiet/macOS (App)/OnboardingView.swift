//
//  OnboardingView.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import SwiftUI
import QuietCore

struct OnboardingView: View {

    @ObservedObject var extensionStatus: ExtensionStatusModel
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Quiet")
                    .font(.largeTitle.weight(.semibold))
                Text("Keep the sites you need. Lose the parts that eat you.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            step(
                number: 1,
                title: "Turn on the Quiet extension in Safari",
                detail: "Safari ships new extensions switched off and never asks. Quiet cannot change anything on a page until you switch it on."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    statusRow
                    HStack {
                        Button("Open Safari Settings…") { extensionStatus.openSafariSettings() }
                            .buttonStyle(.borderedProminent)
                        Button("Check Again") { extensionStatus.refresh() }
                    }
                }
            }

            step(
                number: 2,
                title: "Choose what to hide",
                detail: "Quiet starts with sensible defaults on YouTube. Everything is a toggle, and nothing is hidden that you did not ask for."
            ) { EmptyView() }

            Spacer()

            HStack {
                Spacer()
                Button(extensionStatus.isEnabled ? "Start using Quiet" : "Skip for now") {
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 480)
        .onAppear { extensionStatus.refresh() }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch extensionStatus.state {
        case .enabled:
            Label("Extension is on", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .disabled:
            Label("Extension is off", systemImage: "xmark.circle.fill")
                .foregroundStyle(.orange)
        case .unknown:
            Label("Checking…", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label("Could not check: \(message)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func step<Content: View>(
        number: Int,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 26, height: 26)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                content()
            }
        }
    }
}
