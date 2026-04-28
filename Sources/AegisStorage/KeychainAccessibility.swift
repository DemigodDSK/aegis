// KeychainAccessibility.swift
// Type-safe wrapper around the `kSecAttrAccessible*`
// constants that Apple's Keychain Services API expects as
// CFString.
//
// We do NOT expose the iCloud-syncable variants of these
// constants — Aegis private keys must not leave the device.
// `kSecAttrSynchronizable` stays unset on every write.

import Foundation
import Security

/// Keychain accessibility classes that Aegis supports.
public enum KeychainAccessibility: Sendable, Equatable {

    /// Item is unreachable until the device is first unlocked
    /// after a reboot. After that first unlock, the item is
    /// readable until the next reboot. This-device-only:
    /// item never syncs to iCloud and never restores from a
    /// backup to a different device.
    ///
    /// **Aegis default.** Matches Signal's default policy and
    /// keeps long-term keys usable for background tasks
    /// (notifications, scheduled fetches) once the user has
    /// unlocked the device once after boot.
    case afterFirstUnlockThisDeviceOnly

    /// Item is readable only while the device is currently
    /// unlocked. Stricter than the above — a background task
    /// firing while the screen is off can't decrypt. Suitable
    /// for ephemeral session keys you don't need to access
    /// in the background.
    case whenUnlockedThisDeviceOnly

    /// Item is readable only while the device is unlocked AND
    /// requires a passcode/biometric set. If the user removes
    /// their passcode, the item becomes unreadable.
    /// This-device-only too.
    case whenPasscodeSetThisDeviceOnly

    /// CFString constant suitable for use as the
    /// kSecAttrAccessible attribute value.
    var cfAttribute: CFString {
        switch self {
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
}
