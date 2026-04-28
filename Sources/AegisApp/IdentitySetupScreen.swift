// IdentitySetupScreen.swift
// Run after onboarding (state.onboardingCompleted == true)
// while no local identity exists yet. Asks for a display
// name and generates the post-quantum identity keypair
// (ML-DSA-65 + X25519), persisting both via AppState.
//
// No phone number. No email. No password. No server. The
// whole flow stays on-device — the only network request that
// will ever happen as a result of this screen is the
// (Sprint 8) prekey-bundle upload, and that's a separate
// affordance later.

import AegisCrypto
import SwiftUI

struct IdentitySetupScreen: View {

    @Bindable var state: AppState

    @State private var displayName: String = ""
    @State private var errorMessage: String?
    @State private var generating: Bool = false

    var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: AegisTheme.spacing) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(AegisTheme.accent)

            Text("Pick a display name")
                .font(AegisTheme.title)

            Text("Your display name lives only on this device. We'll generate your post-quantum identity (ML-DSA-65 + X25519) and store it in your Keychain. No server account, no email, no password.")
                .font(AegisTheme.body)
                .foregroundStyle(AegisTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AegisTheme.spacing)

            TextField("e.g. Datta", text: $displayName)
                .textFieldStyle(.plain)
                .padding()
                .background(AegisTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AegisTheme.cornerRadius)
                        .stroke(AegisTheme.surface, lineWidth: 1)
                )
                .padding(.horizontal, AegisTheme.spacing)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(AegisTheme.caption)
                    .foregroundStyle(AegisTheme.destructive)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AegisTheme.spacing)
            }

            Spacer()

            Button(action: generate) {
                Text(generating ? "Generating…" : "Generate identity")
                    .font(AegisTheme.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        trimmedName.isEmpty
                            ? AegisTheme.surface
                            : AegisTheme.accent
                    )
                    .foregroundStyle(
                        trimmedName.isEmpty
                            ? AegisTheme.textSecondary
                            : Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(trimmedName.isEmpty || generating)
        }
    }

    private func generate() {
        guard !trimmedName.isEmpty, !generating else { return }
        generating = true
        defer { generating = false }
        do {
            state.setDisplayName(trimmedName)
            _ = try state.generateAndSaveIdentity()
            errorMessage = nil
        } catch {
            errorMessage = "Could not generate identity: \(error.localizedDescription)"
        }
    }
}
