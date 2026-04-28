// SettingsScreen.swift
// Settings → Security view + About card.
//
// The capability list is rendered from `Capability.all`, which
// mirrors THREAT-MODEL.md §"Cryptographic guarantees by
// version". A row tap toggles an inline disclosure with the
// row's `detail` and a status badge.

import SwiftUI

struct SettingsScreen: View {

    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AegisTheme.spacing) {
                aboutCard
                securitySection
            }
            .padding(AegisTheme.spacing)
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aegis")
                .font(AegisTheme.title)
            Text("Post-quantum messaging, in the open.")
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textSecondary)

            Divider().padding(.vertical, 4)

            kvRow("Version", "v0.0.7-sprint-6 — pre-1.0, library + demo only")
            kvRow("Maintainer", "Datta Sai Krishna N (@DemigodDSK)")

            Link(
                destination: URL(string: "https://github.com/DemigodDSK/aegis")!
            ) {
                Label("github.com/DemigodDSK/aegis", systemImage: "arrow.up.right.square")
                    .font(AegisTheme.body.weight(.medium))
                    .foregroundStyle(AegisTheme.accent)
            }

            kvRow(
                "Maintainer PGP",
                "E7B6 56B4 D0DD BB07 29ED 462F FF11 64C0 B4D2 8DE4"
            )

            if let name = state.displayName {
                Divider().padding(.vertical, 4)
                kvRow("This device", name)
            }
        }
        .padding(AegisTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AegisTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
    }

    // MARK: - Security section

    @ViewBuilder
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: AegisTheme.spacing) {
            Text("Security")
                .font(AegisTheme.heading)
            Text("Mirrored from THREAT-MODEL.md. We do not promise more than this list says we ship.")
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(Capability.all) { cap in
                    CapabilityRow(capability: cap)
                }
            }
        }
    }

    // MARK: - Helpers

    private func kvRow(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key)
                .font(AegisTheme.caption.weight(.semibold))
                .foregroundStyle(AegisTheme.textSecondary)
            Text(value)
                .font(AegisTheme.body)
                .foregroundStyle(AegisTheme.textPrimary)
                .textSelection(.enabled)
        }
    }
}

private struct CapabilityRow: View {

    let capability: Capability

    @State private var expanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    statusGlyph
                    Text(capability.title)
                        .font(AegisTheme.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AegisTheme.textSecondary)
                        .font(.caption)
                }
                .padding(AegisTheme.spacing)
                .background(AegisTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(capability.detail)
                        .font(AegisTheme.caption)
                        .foregroundStyle(AegisTheme.textPrimary)
                    statusFootnote
                        .font(AegisTheme.caption.weight(.semibold))
                        .foregroundStyle(statusTint)
                }
                .padding(.horizontal, AegisTheme.spacing)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var statusGlyph: some View {
        switch capability.status {
        case .shipped:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AegisTheme.accent)
        case .plannedFor:
            Image(systemName: "clock.fill")
                .foregroundStyle(AegisTheme.textSecondary)
        case .partial:
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(AegisTheme.warning)
        case .outOfScope:
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(AegisTheme.textSecondary)
        }
    }

    @ViewBuilder
    private var statusFootnote: some View {
        switch capability.status {
        case .shipped:
            Text("Shipped in this version.")
        case .plannedFor(let target):
            Text("Planned for \(target).")
        case .partial(let note):
            Text("Partial — \(note)")
        case .outOfScope(let reason):
            Text("Out of scope. \(reason)")
        }
    }

    private var statusTint: Color {
        switch capability.status {
        case .shipped: return AegisTheme.accent
        case .plannedFor: return AegisTheme.textSecondary
        case .partial: return AegisTheme.warning
        case .outOfScope: return AegisTheme.textSecondary
        }
    }
}
