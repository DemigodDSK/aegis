// Theme.swift
// Centralised colour palette, typography weights, and layout
// constants for the Aegis SwiftUI surface.
//
// Dark-first by default — the contexts Aegis is built for
// (people reading sensitive messages on phones at night,
// late-night incident response, journalists working from
// hostile environments) all skew toward dark UI.
//
// Light mode is a future polish concern; this file pins one
// dark theme for v0.0.7. Override at the View level only when
// strictly necessary; everything else should pull from these
// constants so a future palette refactor is one place.

import SwiftUI

public enum AegisTheme {

    // MARK: - Colours

    /// App background. Near-black with a hint of warmth so it
    /// doesn't read as pure-OLED-off.
    public static let background = Color(red: 0.04, green: 0.04, blue: 0.05)

    /// Card / row surface, one notch lighter than `background`.
    public static let surface = Color(red: 0.10, green: 0.10, blue: 0.11)

    /// Primary readable foreground.
    public static let textPrimary = Color(white: 0.97)

    /// Subdued text for secondary metadata, captions, hints.
    public static let textSecondary = Color(white: 0.62)

    /// Tinted accent for primary actions, links, focus rings.
    /// A calm desaturated blue — Aegis is a security tool,
    /// not a marketing surface; we don't shout in colour.
    public static let accent = Color(red: 0.36, green: 0.62, blue: 0.93)

    /// Warning accent for "experimental / proceed with care"
    /// Tier-2 cryptography contexts and onboarding's "use
    /// Signal instead" framing.
    public static let warning = Color(red: 0.95, green: 0.74, blue: 0.20)

    /// Destructive accent for delete / sign-out actions
    /// (post-Sprint-6).
    public static let destructive = Color(red: 0.94, green: 0.36, blue: 0.36)

    // MARK: - Layout

    /// Corner radius for cards / buttons / inputs. Slightly
    /// rounder than iOS default to feel modern but not
    /// childish.
    public static let cornerRadius: CGFloat = 12

    /// Default spacing unit for stacks. Multiples of this
    /// (×2, ×3) cover most layout needs.
    public static let spacing: CGFloat = 16

    /// Outer screen padding. Slightly larger than `spacing`
    /// so content feels comfortably inset from the edges.
    public static let screenPadding: CGFloat = 20

    // MARK: - Typography

    /// Display headline (onboarding screen titles, section
    /// hero text).
    public static let display: Font = .system(size: 34, weight: .bold)

    /// Standard screen title (settings, demo screen header).
    public static let title: Font = .system(size: 28, weight: .semibold)

    /// Section / subsection heading inside a screen.
    public static let heading: Font = .system(size: 20, weight: .semibold)

    /// Body copy.
    public static let body: Font = .system(size: 17, weight: .regular)

    /// Caption / footnote / disclaimer.
    public static let caption: Font = .system(size: 13, weight: .regular)
}
