// MainTabView.swift
// The three-tab surface a user lands on after onboarding +
// identity setup: Demo, Conversations, Settings. Wrapped
// here so RootView stays a thin router.
//
// The Conversations tab arrived in Sprint 8 (v0.0.9). It
// reads from the SQLite-backed ConversationStore. With no
// networking yet, the list is populated by the two-user
// toggle (Sprint 8 commit 5).

import SwiftUI

struct MainTabView: View {

    @Bindable var state: AppState

    var body: some View {
        TabView {
            DemoScreen()
                .tabItem {
                    Label("Demo", systemImage: "lock.shield")
                }

            ConversationsListView(state: state)
                .tabItem {
                    Label("Conversations", systemImage: "bubble.left.and.bubble.right")
                }

            SettingsScreen(state: state)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(AegisTheme.accent)
    }
}
