// RootView.swift
// Top-level routing view. Picks between three states:
//
//   1. First launch / onboarding not yet seen → mandatory
//      3-screen honesty flow (lands at commit 3 of this
//      sprint).
//   2. Onboarding done but no identity yet → identity setup
//      (display name + key generation; commit 4).
//   3. Onboarding done + identity present → main app
//      (demo + settings; commits 4-5).
//
// Concrete screens for states 1-3 arrive in subsequent
// commits of this sprint. This commit ships a placeholder
// `MilestoneView` for each so the routing logic itself is
// observable and testable today, and so the app actually
// runs end-to-end via `aegis-demo` after commit 6.

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
            MilestoneView(
                state: .identity,
                action: { _ = try? state.generateAndSaveIdentity() }
            )
        } else {
            MilestoneView(state: .ready, action: nil)
        }
    }
}

/// Stand-in screen for the three top-level routing states.
/// Replaced by real content (onboarding, identity setup,
/// demo, settings) over the next four commits of this
/// sprint; included now so `RootView` actually compiles and
/// the routing logic can be exercised from `AppStateTests`.
struct MilestoneView: View {

    enum Stage {
        case onboarding
        case identity
        case ready

        var title: String {
            switch self {
            case .onboarding: return "Onboarding"
            case .identity:   return "Identity setup"
            case .ready:      return "Aegis"
            }
        }

        var subtitle: String {
            switch self {
            case .onboarding:
                return "Mandatory 3-screen honesty flow lands in commit 3 of this sprint."
            case .identity:
                return "Pick a local display name; we'll generate your post-quantum identity. Lands in commit 4."
            case .ready:
                return "Demo screen + Settings → Security land in commits 4 and 5."
            }
        }

        var actionLabel: String {
            switch self {
            case .onboarding: return "Skip (Sprint 6 in progress)"
            case .identity:   return "Generate identity"
            case .ready:      return ""
            }
        }
    }

    let stage: Stage
    let action: (() -> Void)?

    init(state: Stage, action: (() -> Void)?) {
        self.stage = state
        self.action = action
    }

    var body: some View {
        VStack(spacing: AegisTheme.spacing) {
            Spacer()

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 56))
                .foregroundStyle(AegisTheme.accent)

            Text(stage.title)
                .font(AegisTheme.display)

            Text(stage.subtitle)
                .font(AegisTheme.body)
                .foregroundStyle(AegisTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AegisTheme.spacing)

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text(stage.actionLabel)
                        .font(AegisTheme.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AegisTheme.surface)
                        .foregroundStyle(AegisTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
