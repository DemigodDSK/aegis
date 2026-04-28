// DemoScreen.swift
// The visible "look, the crypto works" surface. Type a
// message, type a passphrase, hit Encrypt → see the
// ciphertext envelope. Hit Decrypt → see the plaintext come
// back. Change the passphrase between Encrypt and Decrypt →
// see the AEAD authentication-failure path light up.
//
// View-model and AEAD logic live in `DemoViewModel`; this
// file is layout only.

import AegisCrypto
import SwiftUI

struct DemoScreen: View {

    @State private var vm = DemoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AegisTheme.spacing) {
                header

                LabeledField(
                    label: "Message",
                    placeholder: "Type something to encrypt…",
                    text: $vm.plaintext
                )

                LabeledField(
                    label: "Passphrase",
                    placeholder: "•••••••",
                    text: $vm.passphrase,
                    isSecret: true
                )

                primaryActions

                if let payload = vm.encryptedPayload {
                    payloadCard(payload)
                }

                if let recovered = vm.decryptedText {
                    recoveredCard(recovered)
                }

                if let error = vm.errorMessage {
                    errorCard(error)
                }
            }
            .padding(AegisTheme.spacing)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Encrypt & decrypt")
                .font(AegisTheme.title)
            Text("AES-256-GCM round-trip with a key derived from your passphrase via HKDF. Ciphertext stays on this device — there is no network.")
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textSecondary)
        }
    }

    // MARK: - Primary actions

    @ViewBuilder
    private var primaryActions: some View {
        HStack(spacing: AegisTheme.spacing) {
            Button(action: vm.encrypt) {
                Text("Encrypt")
                    .font(AegisTheme.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canEncrypt ? AegisTheme.accent : AegisTheme.surface)
                    .foregroundStyle(canEncrypt ? Color.white : AegisTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(!canEncrypt)

            Button(action: vm.decrypt) {
                Text("Decrypt")
                    .font(AegisTheme.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canDecrypt ? AegisTheme.accent : AegisTheme.surface)
                    .foregroundStyle(canDecrypt ? Color.white : AegisTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(!canDecrypt)
        }
    }

    private var canEncrypt: Bool {
        !vm.plaintext.isEmpty && !vm.passphrase.isEmpty
    }

    private var canDecrypt: Bool {
        vm.encryptedPayload != nil && !vm.passphrase.isEmpty
    }

    // MARK: - Result cards

    private func payloadCard(_ payload: EncryptedPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ciphertext envelope")
                .font(AegisTheme.heading)
            kvRow("methodId", payload.methodId)
            kvRow("nonce", payload.nonce.base64EncodedString())
            kvRow("ciphertext", payload.ciphertext.base64EncodedString())
            kvRow("tag", payload.tag.base64EncodedString())
        }
        .padding(AegisTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AegisTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
    }

    private func recoveredCard(_ recovered: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recovered plaintext")
                .font(AegisTheme.heading)
            Text(recovered)
                .font(AegisTheme.body)
                .foregroundStyle(AegisTheme.accent)
                .textSelection(.enabled)
        }
        .padding(AegisTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AegisTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
    }

    private func errorCard(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AegisTheme.destructive)
            Text(error)
                .font(AegisTheme.caption)
                .foregroundStyle(AegisTheme.textPrimary)
        }
        .padding(AegisTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AegisTheme.destructive.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
    }

    private func kvRow(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key)
                .font(AegisTheme.caption.weight(.semibold))
                .foregroundStyle(AegisTheme.textSecondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AegisTheme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Tiny components used by Demo + Identity setup

struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecret: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AegisTheme.caption.weight(.semibold))
                .foregroundStyle(AegisTheme.textSecondary)

            Group {
                if isSecret {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .padding()
            .background(AegisTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AegisTheme.cornerRadius))
        }
    }
}
