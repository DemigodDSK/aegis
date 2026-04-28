// ConversationThreadView.swift
// One conversation's message log. Outbound messages on the
// right (accent), inbound on the left (surface). Composer at
// the bottom sends via the ConversationStore — wired for both
// sides by Sprint 8 commit 5's two-user toggle.

import AegisStorage
import SwiftUI

struct ConversationThreadView: View {

    @Bindable var state: AppState
    let conversation: Conversation

    @State private var messages: [StoredMessage] = []
    @State private var composer: String = ""
    @State private var errorMessage: String?

    /// Optional external handler — when set, "send" calls it
    /// rather than posting through `state.conversationStore`
    /// directly. Sprint 8 commit 5 uses this hook so that the
    /// two-user toggle can deliver the wire message to the
    /// peer's local conversation as well.
    var onSend: ((Data) -> Void)?

    var body: some View {
        ZStack {
            AegisTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }

                if let error = errorMessage {
                    errorBanner(error)
                }

                composerBar
            }
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayModeIfAvailable()
        .onAppear { reload() }
    }

    // MARK: - Reload

    private func reload() {
        state.setupDatabase()
        guard let store = state.conversationStore else {
            errorMessage = "conversation store unavailable"
            return
        }
        do {
            messages = try store.messages(in: conversation.id)
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(messages, id: \.id) { message in
                        bubble(for: message)
                            .id(message.id)
                    }
                }
                .padding(AegisTheme.spacing)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(for message: StoredMessage) -> some View {
        let text = String(data: message.plaintext, encoding: .utf8)
            ?? "(non-UTF-8 payload)"
        let isOutgoing = message.direction == .outgoing
        HStack {
            if isOutgoing { Spacer(minLength: 40) }
            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
                Text(text)
                    .font(AegisTheme.body)
                    .foregroundStyle(isOutgoing ? Color.white : AegisTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isOutgoing ? AegisTheme.accent : AegisTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
                Text("#\(message.messageNumber)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AegisTheme.textSecondary)
            }
            if !isOutgoing { Spacer(minLength: 40) }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.system(size: 36))
                .foregroundStyle(AegisTheme.textSecondary)
            Text("No messages yet")
                .font(AegisTheme.heading)
                .foregroundStyle(AegisTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Composer

    @ViewBuilder
    private var composerBar: some View {
        HStack(spacing: 8) {
            TextField("Message…", text: $composer, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AegisTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
                .lineLimit(1...4)

            Button(action: sendComposer) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(canSend ? Color.white : AegisTheme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(canSend ? AegisTheme.accent : AegisTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(AegisTheme.spacing)
        .background(AegisTheme.background)
    }

    private var canSend: Bool {
        !composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendComposer() {
        let trimmed = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let plaintext = Data(trimmed.utf8)
        composer = ""

        if let onSend = onSend {
            // Two-user toggle (commit 5) takes over the
            // delivery flow.
            onSend(plaintext)
            reload()
            return
        }

        guard let store = state.conversationStore else {
            errorMessage = "conversation store unavailable"
            return
        }
        do {
            _ = try store.send(plaintext: plaintext, in: conversation.id)
            reload()
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AegisTheme.destructive)
            Text(error)
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, AegisTheme.spacing)
        .padding(.vertical, 8)
        .background(AegisTheme.destructive.opacity(0.12))
    }
}

// MARK: - iOS / macOS shim

private extension View {
    /// `.navigationBarTitleDisplayMode(.inline)` is iOS-only;
    /// macOS demo (`aegis-demo`) lacks the API. This shim
    /// applies it where available and is a no-op otherwise.
    @ViewBuilder
    func navigationBarTitleDisplayModeIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
