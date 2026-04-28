// DemoViewModelTests.swift
// Logic tests for the demo-screen view-model. The view layer
// is not exercised; this hits the encrypt / decrypt path the
// view binds to.

import AegisCrypto
@testable import AegisApp
import XCTest

@MainActor
final class DemoViewModelTests: XCTestCase {

    // MARK: - Initial state

    func testInit_emptyState() {
        let vm = DemoViewModel()
        XCTAssertEqual(vm.plaintext, "")
        XCTAssertEqual(vm.passphrase, "")
        XCTAssertNil(vm.encryptedPayload)
        XCTAssertNil(vm.decryptedText)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Encrypt

    func testEncrypt_withInputs_producesPayload() {
        let vm = DemoViewModel()
        vm.plaintext = "hello aegis"
        vm.passphrase = "passphrase-1234"

        vm.encrypt()

        XCTAssertNotNil(vm.encryptedPayload)
        XCTAssertNil(vm.decryptedText, "encrypt should clear any prior decrypted result")
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.encryptedPayload?.methodId, AESGCM.methodId)
    }

    func testEncrypt_emptyPlaintext_isNoOp() {
        let vm = DemoViewModel()
        vm.passphrase = "set"
        vm.encrypt()
        XCTAssertNil(vm.encryptedPayload)
    }

    func testEncrypt_emptyPassphrase_isNoOp() {
        let vm = DemoViewModel()
        vm.plaintext = "set"
        vm.encrypt()
        XCTAssertNil(vm.encryptedPayload)
    }

    // MARK: - Decrypt round-trip

    func testDecrypt_withSamePassphrase_recoversPlaintext() {
        let vm = DemoViewModel()
        vm.plaintext = "round-trip me"
        vm.passphrase = "correct-horse-battery-staple"

        vm.encrypt()
        XCTAssertNotNil(vm.encryptedPayload)

        // Clear plaintext to make sure decrypt isn't echoing
        // the field rather than actually decrypting.
        vm.plaintext = ""
        vm.decrypt()
        XCTAssertEqual(vm.decryptedText, "round-trip me")
        XCTAssertNil(vm.errorMessage)
    }

    func testDecrypt_withWrongPassphrase_setsErrorMessage() {
        let vm = DemoViewModel()
        vm.plaintext = "secret"
        vm.passphrase = "right"
        vm.encrypt()
        XCTAssertNotNil(vm.encryptedPayload)

        vm.passphrase = "wrong"
        vm.decrypt()

        XCTAssertNil(vm.decryptedText, "decrypt with wrong passphrase must not produce plaintext")
        XCTAssertNotNil(vm.errorMessage,
                        "decrypt with wrong passphrase must surface an error")
    }

    func testDecrypt_withoutPriorEncrypt_isNoOp() {
        let vm = DemoViewModel()
        vm.passphrase = "anything"
        vm.decrypt()
        XCTAssertNil(vm.decryptedText)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Reset

    func testReset_clearsEverything() {
        let vm = DemoViewModel()
        vm.plaintext = "x"
        vm.passphrase = "y"
        vm.encrypt()
        vm.decrypt()

        vm.reset()
        XCTAssertNil(vm.encryptedPayload)
        XCTAssertNil(vm.decryptedText)
        XCTAssertNil(vm.errorMessage)
        // The user's input fields are not reset by design
        // (the user can keep editing without losing what
        // they typed).
        XCTAssertEqual(vm.plaintext, "x")
        XCTAssertEqual(vm.passphrase, "y")
    }
}
