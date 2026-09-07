//
//  QuietUI.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import AppKit
import SwiftUI

/// Small shared pieces so the screens stop restating the same layout, and so long
/// explanations have somewhere to live other than the middle of the window.

/// Moves a paragraph out of the main flow into a popover behind an ⓘ.
///
/// The app previously explained itself in captions under almost every control, which made
/// a short settings screen read like documentation. The explanations are still worth having
/// (several describe real limitations people would otherwise file as bugs), so they move
/// here rather than being deleted.
struct InfoButton: View {
    let text: String
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(text)
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 280, alignment: .leading)
                .padding(14)
        }
    }
}

/// The real icon of an installed application, looked up from its bundle identifier.
///
/// Falls back to a generic symbol rather than showing nothing: the lookup goes through
/// LaunchServices, which can fail for an app that has since been deleted or moved, and a
/// blocked-apps list of unlabelled blanks would be worse than a row of placeholders.
struct AppIconView: View {
    let bundleIdentifier: String
    var size: CGFloat = 28

    private var icon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// A site's favicon, fetched by Safari's own cache rather than the network.
///
/// There is no offline way to get a real favicon, and this app makes a point of not talking
/// to the network, so this is a coloured monogram instead: recognisable at a glance in a
/// list, honest about being generated rather than official.
struct SiteMonogram: View {
    let domain: String
    var size: CGFloat = 28

    private var letter: String {
        String(domain.prefix(1)).uppercased()
    }

    /// Deterministic per domain, so a site keeps the same colour between launches.
    private var tint: Color {
        let hues: [Color] = [.blue, .purple, .pink, .orange, .green, .teal, .indigo]
        let hash = domain.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        return hues[hash % hues.count]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(letter)
                    .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }
}

/// A row that deletes itself, with the control kept quiet until the pointer is over it.
struct RemovableRow<Content: View>: View {
    let onRemove: () -> Void
    var isRemovable = true
    @ViewBuilder var content: Content

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            content
            Spacer(minLength: 8)
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .opacity(isHovering && isRemovable ? 1 : 0)
            .disabled(!isRemovable)
            .accessibilityLabel("Remove")
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

/// One short line and a symbol, for a list with nothing in it yet.
struct EmptyHint: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.tertiary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 10)
    }
}

/// A single coloured strip for something that needs attention now, such as the Safari
/// extension being switched off. Deliberately one line: a banner people read is short.
struct NoticeBar: View {
    let symbol: String
    let message: String
    let actionTitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(message)
                .font(.callout)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(actionTitle, action: action)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(tint.opacity(0.12))
    }
}
