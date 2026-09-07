//
//  QuietFocusFilter.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import AppIntents
import Foundation
import QuietCore

/// One of the user's Focus links, as it appears in the System Settings picker when they add
/// Quiet as a Focus Filter.
struct FocusProfileEntity: AppEntity {

    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Quiet Focus" }
    static var defaultQuery: FocusProfileQuery { FocusProfileQuery() }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct FocusProfileQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [FocusProfileEntity] {
        let wanted = Set(identifiers)
        return allProfiles().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [FocusProfileEntity] {
        allProfiles()
    }

    /// "Any Focus" is always offered so the common case works with no setup inside Quiet:
    /// add the filter, pick Any Focus, done. Named links come after it, for people who want
    /// one Focus to block and another not to.
    private func allProfiles() -> [FocusProfileEntity] {
        ([FocusPolicy.anyFocus] + BlockPolicyStore.load().focusProfiles)
            .map { FocusProfileEntity(id: $0.id, name: $0.name) }
    }
}

/// Lets a macOS Focus turn Quiet's blocking on and off.
///
/// This is the only public way to know a named Focus is running: there is no API to ask.
/// The user adds Quiet under System Settings, Focus, [a Focus], Focus Filters, once per
/// Focus, and the system then performs this intent when that Focus starts and again when it
/// ends. `FocusMonitor` reconciles against `current` afterwards, because a push that
/// arrives while Quiet is not running is simply never delivered.
struct QuietFocusFilter: SetFocusFilterIntent {

    static let title: LocalizedStringResource = "Turn on Quiet"

    static var description: IntentDescription? {
        IntentDescription("Blocks the websites and apps on your Quiet list while this Focus is on.")
    }

    /// Optional, and it must stay optional. When a Focus ends the system has no value to
    /// supply for this parameter, so a non optional one causes the deactivation to be
    /// dropped instead of performed: blocking would switch on with the Focus and then never
    /// switch off. The nil case is precisely how "this Focus ended" arrives.
    @Parameter(title: "Quiet Focus")
    var profile: FocusProfileEntity?

    var displayRepresentation: DisplayRepresentation {
        guard let profile else {
            return DisplayRepresentation(title: "Not blocking")
        }
        return DisplayRepresentation(title: "\(profile.name)")
    }

    func perform() async throws -> some IntentResult {
        if let profile {
            FocusStateStore.activate(profile.id)
        } else {
            FocusStateStore.clear()
        }
        FocusChangeSignal.post()
        return .result()
    }
}

/// Wakes whichever Quiet process is running when the Focus Filter changes the stored state.
///
/// A Darwin notification rather than a plain `NotificationCenter` post because the intent
/// is not guaranteed to run inside the running app: the system may perform it in a separate
/// process, and a same process notification would then reach nobody. Darwin notifications
/// cross the sandbox boundary and are delivered to the posting process too, so one path
/// covers both cases.
enum FocusChangeSignal {

    private static let darwinName = "CU82DCKHTL.group.com.app.Quiet.focusDidChange" as CFString

    static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinName),
            nil,
            nil,
            true
        )
    }

    /// Re-posts the Darwin notification as an ordinary local one, so observers can use
    /// NotificationCenter and capture context. The C callback cannot capture anything, which
    /// is why it hands off rather than calling a handler directly.
    static func startObserving() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .quietFocusDidChange, object: nil)
                }
            },
            darwinName,
            nil,
            .deliverImmediately
        )
    }
}

extension Notification.Name {
    static let quietFocusDidChange = Notification.Name("quiet.focusDidChange")
}
