// CoachMark.swift
// One contextual hint. `arrowEdge` is the side of the bubble the arrow points
// FROM toward the target (e.g. .bottom = bubble sits above the target, arrow
// points down). Storage is local (per device) — see CoachMarkStore.

import SwiftUI

enum CoachMark: String, CaseIterable, Identifiable {
    case readArticleLongPress
    case storySwipe
    case commentLongPress
    case iPadDividerResize

    var id: String { rawValue }

    var storageKey: String { "LN_coach_" + rawValue }

    var text: String {
        switch self {
        case .readArticleLongPress: return "Hold to open in Reader, Safari, or in-app."
        case .storySwipe:           return "Swipe a story for quick actions. Customise them in Settings."
        case .commentLongPress:     return "Long-press a comment for more actions."
        case .iPadDividerResize:    return "Drag to resize the columns."
        }
    }

    /// Side of the bubble the arrow emerges from, toward the target.
    var arrowEdge: Edge {
        switch self {
        case .readArticleLongPress: return .bottom   // bubble above the button
        case .storySwipe:           return .bottom   // bubble above the first row
        case .commentLongPress:     return .bottom   // bubble above the comment
        case .iPadDividerResize:    return .leading  // bubble right of the divider
        }
    }
}

/// First mark, in declared order, that is both unseen and currently anchored
/// (its target view is on screen). Pure so it can be unit-tested.
func firstEligibleCoachMark(in marks: [CoachMark],
                            seen: Set<CoachMark>,
                            anchored: Set<CoachMark>) -> CoachMark? {
    marks.first { !seen.contains($0) && anchored.contains($0) }
}
