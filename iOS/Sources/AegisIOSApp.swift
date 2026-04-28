// AegisIOSApp.swift
// iOS @main entry point. Mirrors the macOS aegis-demo
// AegisDemoApp.swift — both targets are tiny shells that
// hand `RootView` to a SwiftUI scene. All views, state, and
// crypto live in the AegisApp / AegisStorage / AegisCrypto
// libraries so the surface stays single-source.

import AegisApp
import SwiftUI

@main
struct AegisIOSApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView(state: appState)
        }
    }
}
