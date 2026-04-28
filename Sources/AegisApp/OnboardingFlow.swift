// OnboardingFlow.swift
// The 3-screen mandatory honesty flow that runs before any
// other interaction with Aegis. Implements the commitments
// recorded in THREAT-MODEL.md "In-app honesty" §"First-launch
// onboarding (mandatory, cannot be skipped)" — the user must
// tap through every screen before reaching the rest of the
// app.
//
// Each screen pairs a clear primary message with a disclosure
// link to either an inline explainer (commit 5 wires up
// Settings → About) or directly to THREAT-MODEL.md on
// GitHub. Screen 3 carries the "use Signal instead for
// life-or-liberty situations" framing that working principle
// 3 (honesty over marketing) requires.

import SwiftUI

private let threatModelURL = URL(string:
    "https://github.com/DemigodDSK/aegis/blob/main/THREAT-MODEL.md")!

/// Mandatory 3-screen onboarding. Replaces
/// `MilestoneView(.onboarding)` from RootView's commit-2
/// placeholder.
struct OnboardingFlow: View {

    @Bindable var state: AppState

    @State private var screenIndex: Int = 0

    var body: some View {
        switch screenIndex {
        case 0:
            WhatWeProtectScreen(advance: advance)
        case 1:
            WhatWeDoNotProtectScreen(advance: advance)
        default:
            IsThisRightForYouScreen(complete: complete)
        }
    }

    private func advance() {
        screenIndex += 1
    }

    private func complete() {
        state.markOnboardingComplete()
    }
}

// MARK: - Screen 1

private struct WhatWeProtectScreen: View {
    let advance: () -> Void

    var body: some View {
        OnboardingScaffold(
            stepLabel: "1 of 3",
            icon: "lock.shield.fill",
            iconTint: AegisTheme.accent,
            title: "What we protect",
            primaryButtonLabel: "Continue",
            primaryButtonAction: advance
        ) {
            VStack(alignment: .leading, spacing: AegisTheme.spacing) {
                Text("Your message content is encrypted end-to-end with post-quantum cryptography. Even our servers cannot read what you send.")
                    .font(AegisTheme.body)

                Link(destination: threatModelURL) {
                    Label("How does this work?", systemImage: "arrow.up.right.square")
                        .font(AegisTheme.body.weight(.medium))
                        .foregroundStyle(AegisTheme.accent)
                }
            }
        }
    }
}

// MARK: - Screen 2

private struct WhatWeDoNotProtectScreen: View {
    let advance: () -> Void

    var body: some View {
        OnboardingScaffold(
            stepLabel: "2 of 3",
            icon: "exclamationmark.triangle.fill",
            iconTint: AegisTheme.warning,
            title: "What we do NOT protect",
            primaryButtonLabel: "Continue",
            primaryButtonAction: advance
        ) {
            VStack(alignment: .leading, spacing: AegisTheme.spacing) {
                BulletText(
                    "Our servers can still see WHO you talk to and WHEN. They cannot see WHAT you say, but the pattern of your conversations is visible."
                )

                BulletText(
                    "We cannot protect you if your phone is compromised, if you are forced to unlock it, or if your contact's phone is compromised."
                )

                Link(destination: threatModelURL) {
                    Label("Read our full threat model", systemImage: "arrow.up.right.square")
                        .font(AegisTheme.body.weight(.medium))
                        .foregroundStyle(AegisTheme.accent)
                }
            }
        }
    }
}

// MARK: - Screen 3

private struct IsThisRightForYouScreen: View {
    let complete: () -> Void

    var body: some View {
        OnboardingScaffold(
            stepLabel: "3 of 3",
            icon: "person.fill.questionmark",
            iconTint: AegisTheme.accent,
            title: "Is Aegis right for you?",
            primaryButtonLabel: "Begin",
            primaryButtonAction: complete
        ) {
            VStack(alignment: .leading, spacing: AegisTheme.spacing) {
                AssessmentRow(
                    glyph: "checkmark.circle.fill",
                    glyphTint: AegisTheme.accent,
                    text: "I want better privacy than iMessage or WhatsApp.",
                    answer: "Use this app."
                )

                AssessmentRow(
                    glyph: "checkmark.circle.fill",
                    glyphTint: AegisTheme.accent,
                    text: "I am a journalist, lawyer, or professional handling confidential matters.",
                    answer: "Use this app, with the metadata caveat in mind."
                )

                AssessmentRow(
                    glyph: "xmark.octagon.fill",
                    glyphTint: AegisTheme.warning,
                    text: "My personal safety, freedom, or life depends on no one knowing who I am communicating with.",
                    answer: "Do not rely on this app yet. Use Signal. We will tell you when we are ready for your threat model — currently planned for v2.0."
                )
            }
        }
    }
}

// MARK: - Shared scaffold

/// One-screen layout used by every onboarding screen.
/// Step label at the top, icon hero, title, slot for body
/// content, primary action button at the bottom.
private struct OnboardingScaffold<Body: View>: View {
    let stepLabel: String
    let icon: String
    let iconTint: Color
    let title: String
    let primaryButtonLabel: String
    let primaryButtonAction: () -> Void
    @ViewBuilder let bodyContent: () -> Body

    var body: some View {
        VStack(spacing: AegisTheme.spacing) {
            HStack {
                Text(stepLabel)
                    .font(AegisTheme.caption)
                    .foregroundStyle(AegisTheme.textSecondary)
                Spacer()
            }

            Spacer().frame(maxHeight: 24)

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(iconTint)

            Text(title)
                .font(AegisTheme.title)
                .multilineTextAlignment(.center)

            ScrollView {
                bodyContent()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AegisTheme.spacing)
            }

            Button(action: primaryButtonAction) {
                Text(primaryButtonLabel)
                    .font(AegisTheme.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AegisTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Tiny components

private struct BulletText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(AegisTheme.body.weight(.bold))
                .foregroundStyle(AegisTheme.accent)
            Text(text)
                .font(AegisTheme.body)
        }
    }
}

private struct AssessmentRow: View {
    let glyph: String
    let glyphTint: Color
    let text: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: glyph)
                    .foregroundStyle(glyphTint)
                    .font(.title3)
                Text(text)
                    .font(AegisTheme.body)
            }
            Text(answer)
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textSecondary)
                .padding(.leading, 32)
        }
        .padding(AegisTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AegisTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
    }
}
