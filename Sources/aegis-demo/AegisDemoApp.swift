// AegisDemoApp.swift
// Tiny macOS SwiftUI App host for the AegisApp library so
// that `swift run aegis-demo` opens a window and exercises
// the full onboarding → identity setup → demo + settings
// flow with real Keychain persistence.
//
// This target's only job is to be the @main entry point.
// All views, state, and crypto live in the AegisApp /
// AegisStorage / AegisCrypto libraries so they can also be
// hosted by Sprint 7's iOS Xcode project (and any other
// future host) without duplication.

import AegisApp
import SwiftUI

@main
struct AegisDemoApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("Aegis (demo)") {
            RootView(state: appState)
                .frame(minWidth: 420, minHeight: 720)
        }
        .windowResizability(.contentSize)
    }
}
