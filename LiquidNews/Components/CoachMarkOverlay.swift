// CoachMarkOverlay.swift
// SwiftUI plumbing for contextual coach marks:
//   • CoachMarkAnchorKey   — collects each target's on-screen frame by mark id.
//   • CoachMarkController   — environment object; targets report their own gesture
//                             firing so the active bubble can dismiss on interaction.
//   • .coachMarkTarget(_:)  — attach to a target view to publish its anchor.
//   • .coachMarks(_:)       — attach at a screen root to render the active bubble.
//   • CoachMarkBubble       — the glass hint bubble + arrow.

import SwiftUI

// MARK: - Anchor preference

struct CoachMarkAnchorKey: PreferenceKey {
    static let defaultValue: [CoachMark: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachMark: Anchor<CGRect>],
                       nextValue: () -> [CoachMark: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Interaction controller

/// Lets a target view tell the active coach mark "my own gesture just fired" so
/// the bubble can dismiss on first interaction. Placed in the environment by
/// `.coachMarks`; targets read it optionally, so they work with or without it.
@Observable
final class CoachMarkController {
    var interacted: Set<CoachMark> = []
    func reportInteraction(_ mark: CoachMark) { interacted.insert(mark) }
}

// MARK: - Target modifier

extension View {
    /// Publishes this view's bounds as the anchor for `mark`.
    func coachMarkTarget(_ mark: CoachMark) -> some View {
        anchorPreference(key: CoachMarkAnchorKey.self, value: .bounds) { [mark: $0] }
    }
}
