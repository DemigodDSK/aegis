// RootView.swift
// Top-level routing view. Picks between three states:
//
//   1. !onboardingCompleted               → mandatory 3-screen
//                                            honesty flow.
//   2. onboardingCompleted, identity=nil  → identity setup.
//   3. identity != nil                    → main app surface
//                                            (demo + settings).
//
// State 3 currently shows the demo screen alone; commit 5 of
// this sprint wraps it in a TabView with Settings → Security.

import SwiftUI

/// The single top-level view a host scene hands to its
/// `WindowGroup` / `Window`. Branches on `AppState`.
public struct RootView: View {

    @Bindable var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        ZStack {
            AegisTheme.background
                .ignoresSafeArea()

            content
                .foregroundStyle(AegisTheme.textPrimary)
        }
        // Aegis is dark-first by design (see Theme.swift's
        // header comment). Force the colour scheme at the
        // root so the iOS-default light-mode background of
        // TabView, ScrollView etc. doesn't bleed through and
        // turn our charcoal screens white-on-white.
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        if !state.onboardingCompleted {
            OnboardingFlow(state: state)
                .padding(AegisTheme.screenPadding)
        } else if state.identity == nil {
            IdentitySetupScreen(state: state)
                .padding(AegisTheme.screenPadding)
        } else {
            // No outer padding on the TabView — the bar
            // itself needs to extend to the screen edges,
            // and each tab handles its own content padding.
            MainTabView(state: state)
        }
    }
}
