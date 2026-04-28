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
                .padding(AegisTheme.screenPadding)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !state.onboardingCompleted {
            OnboardingFlow(state: state)
        } else if state.identity == nil {
            IdentitySetupScreen(state: state)
        } else {
            // Main app surface. Commit 5 wraps this in a
            // TabView with Settings → Security alongside.
            DemoScreen()
        }
    }
}
