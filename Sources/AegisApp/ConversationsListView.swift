// ConversationsListView.swift
// The Conversations tab — a list of every locally-defined
// conversation, with a row per conversation showing the peer's
// display name and the time of its most recent activity.
//
// Empty state: a clear "No conversations yet" card. Sprint 8
// commit 5 wires the two-user toggle that actually creates
// conversations; until then this list is empty by design (we
// don't render fake-functional conversations — working
// principle 6, "don't promise more than you ship").

import AegisStorage
import SwiftUI

struct ConversationsListView: View {

    @Bindable var state: AppState

    /// External hook so the parent (RootView /
    /// MainTabView) can present a "create conversation"
    /// affordance — wired in Sprint 8 commit 5.
    var onCreateConversation: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                AegisTheme.background.ignoresSafeArea()

                Group {
                    if let error = state.databaseError {
                        errorCard(error)
                    } else if state.conversations.isEmpty {
                        emptyState
                    } else {
                        conversationList
                    }
                }
                .padding(AegisTheme.spacing)
            }
            .navigationTitle("Conversations")
            .toolbar {
                if let onCreate = onCreateConversation {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: onCreate) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AegisTheme.accent)
                                .accessibilityLabel("New conversation")
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

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(AegisTheme.textSecondary)
            Text("No conversations yet")
                .font(AegisTheme.heading)
                .foregroundStyle(AegisTheme.textPrimary)
            Text("Aegis has no networking in v0.0.9 — this list will populate once you create a local two-user conversation.")
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AegisTheme.spacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    @ViewBuilder
    private var conversationList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(state.conversations, id: \.id) { conversation in
                    NavigationLink {
                        ConversationThreadView(state: state, conversation: conversation)
                    } label: {
                        row(for: conversation)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(for conversation: Conversation) -> some View {
        HStack(spacing: AegisTheme.spacing) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 32))
                .foregroundStyle(AegisTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.displayName)
                    .font(AegisTheme.body.weight(.semibold))
                    .foregroundStyle(AegisTheme.textPrimary)
                Text(formatted(unixTime: conversation.updatedAt))
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

    private func formatted(unixTime: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unixTime))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
