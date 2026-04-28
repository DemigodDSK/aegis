// MainTabView.swift
// The two-tab surface a user lands on after onboarding +
// identity setup: Demo and Settings. Wrapped here so RootView
// stays a thin router.
//
// We deliberately do NOT include placeholder Messages or
// Contacts tabs at v0.0.7. There is no networking yet
// (Sprint 8) — showing fake-functional tabs would violate
// working principle 6 ("don't promise more than you ship").
// Those tabs land when they actually do something.

import SwiftUI

struct MainTabView: View {

    @Bindable var state: AppState

    var body: some View {
        TabView {
            DemoScreen()
                .tabItem {
                    Label("Demo", systemImage: "lock.shield")
                }

            SettingsScreen(state: state)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(AegisTheme.accent)
    }
}
