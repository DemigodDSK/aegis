// ConversationsListView.swift
// The Conversations tab. With Sprint 8 commit 5 wired in,
// this is the entry point to the two-user demo: a persona
// segmented control ("I am Alice / I am Bob") at the top, a
// single conversation row showing the active persona's view,
// and a "start the demo" button when nothing has been
// bootstrapped yet.

import AegisStorage
import SwiftUI

struct ConversationsListView: View {

    @Bindable var state: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                AegisTheme.background.ignoresSafeArea()

                Group {
                    if let error = state.databaseError {
                        errorCard(error)
                    } else if let demo = state.twoUserDemo, demo.isBootstrapped {
                        bootstrappedList(demo)
                    } else {
                        bootstrapPrompt
                    }
                }
                .padding(AegisTheme.spacing)
            }
            .navigationTitle("Conversations")
            .toolbar {
                if let demo = state.twoUserDemo, !demo.isBootstrapped {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { state.bootstrapTwoUserDemo() }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AegisTheme.accent)
                                .accessibilityLabel("Start two-user demo")
                        }
                    }
                }
            }
        }
        .onAppear {
            state.setupDatabase()
            try? state.refreshConversations()
        }
    }

    // MARK: - Pre-bootstrap

    @ViewBuilder
    private var bootstrapPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(AegisTheme.textSecondary)
            Text("No conversations yet")
                .font(AegisTheme.heading)
                .foregroundStyle(AegisTheme.textPrimary)
            Text("Aegis has no networking in v0.0.9. Tap + to start the local two-user demo — Alice and Bob will be generated, run a full PQXDH handshake, and exchange messages on this device.")
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AegisTheme.spacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bootstrapped list

    @ViewBuilder
    private func bootstrappedList(_ demo: TwoUserDemo) -> some View {
        VStack(spacing: AegisTheme.spacing) {
            personaPicker(demo)

            if let active = demo.activeConversation {
                NavigationLink {
                    ConversationThreadView(
                        state: state,
                        conversation: active,
                        onSend: { plaintext in
                            state.sendFromActivePersona(plaintext)
                        }
                    )
                } label: {
                    row(for: active, persona: demo.activePersona)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func personaPicker(_ demo: TwoUserDemo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Acting as")
                .font(AegisTheme.caption.weight(.semibold))
                .foregroundStyle(AegisTheme.textSecondary)

            Picker(
                "Active persona",
                selection: Binding(
                    get: { demo.activePersona },
                    set: { demo.setActivePersona($0) }
                )
            ) {
                Text(TwoUserPersona.alice.displayName).tag(TwoUserPersona.alice)
                Text(TwoUserPersona.bob.displayName).tag(TwoUserPersona.bob)
            }
            .pickerStyle(.segmented)
        }
    }

    private func row(for conversation: Conversation, persona: TwoUserPersona) -> some View {
        HStack(spacing: AegisTheme.spacing) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 32))
                .foregroundStyle(AegisTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.displayName)
                    .font(AegisTheme.body.weight(.semibold))
                    .foregroundStyle(AegisTheme.textPrimary)
                Text("Chatting as \(persona.displayName)")
                    .font(AegisTheme.caption)
                    .foregroundStyle(AegisTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AegisTheme.textSecondary)
        }
        .padding(AegisTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AegisTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
    }

    // MARK: - Error

    private func errorCard(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AegisTheme.destructive)
            Text("Couldn't open the conversation store: \(error)")
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textPrimary)
        }
        .padding(AegisTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AegisTheme.destructive.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
    }
}
