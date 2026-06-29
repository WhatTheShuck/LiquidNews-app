// CoachMark.swift
// One contextual hint. `arrowEdge` is the side of the bubble the arrow points
// FROM toward the target (e.g. .bottom = bubble sits above the target, arrow
// points down). Storage is local (per device) — see CoachMarkStore.

import SwiftUI

enum CoachMark: String, CaseIterable, Identifiable {
    case readArticleLongPress
    case storySwipe
    case commentLongPress
    case commentTapCollapse
    case iPadDividerResize
    case resumeBanner
    case readerAppearance
    case feedIntro
    case curatedIntro
    case catchUpIntro
    case favouritesIntro
    case readLaterIntro

    var id: String { rawValue }

    var storageKey: String { "LN_coach_" + rawValue }

    var text: String {
        switch self {
        case .readArticleLongPress: return "Hold to open in Reader, Safari, or in-app. Set your default tap action in Settings."
        case .storySwipe:           return "Swipe a story for quick actions. Customise them in Settings."
        case .commentLongPress:     return "Long-press a comment for more actions."
        case .commentTapCollapse:   return "Tap a comment to collapse its replies. Tap again to expand."
        case .iPadDividerResize:    return "Drag to resize the columns."
        case .resumeBanner:         return "Pick up where you left off here. Other devices appear below — swipe to dismiss, or turn it off in Settings."
        case .readerAppearance:     return "Tap the text icon, top right, to change font, size, and theme — eight reading themes to choose from."
        case .feedIntro:            return "Hacker News, just as you'd expect. Switch categories along the top — add or reorder them in Settings."
        case .curatedIntro:         return "Hand-picked stories from a popular Hacker News newsletter, refreshed weekly — plus Liquid News picks. Add your own sources in Settings."
        case .catchUpIntro:         return "Been away? Catch up on the top stories from any stretch of time you choose."
        case .favouritesIntro:      return "Stories you've starred to keep. They stay here until you remove them."
        case .readLaterIntro:       return "Your reading queue — save stories to finish later. The badge counts what's still unread."
        }
    }

    /// Banner marks explain a whole screen and have no gesture target, so they
    /// render as an arrow-less card pinned below the nav bar rather than a bubble
    /// pointing at an anchor. They are eligible whenever their host screen appears.
    var isBanner: Bool {
        switch self {
        case .readerAppearance, .feedIntro, .curatedIntro,
             .catchUpIntro, .favouritesIntro, .readLaterIntro:
            return true
        default:
            return false
        }
    }

    /// Side of the bubble the arrow emerges from, toward the target. Unused by
    /// banner marks.
    var arrowEdge: Edge {
        switch self {
        case .readArticleLongPress: return .bottom   // bubble above the button
        case .storySwipe:           return .bottom   // bubble above the first row
        case .commentLongPress:     return .bottom   // bubble above the comment
        case .commentTapCollapse:   return .bottom   // bubble above the comment
        case .iPadDividerResize:    return .leading  // bubble right of the divider
        case .resumeBanner:         return .top      // bubble below the top-pinned banner
        default:                    return .bottom   // banners ignore this
        }
    }

    /// When true, the bubble shows left/right swipe chevrons instead of a single
    /// pointing arrow — communicates a horizontal swipe gesture.
    var isSwipeHint: Bool {
        switch self {
        case .storySwipe: return true
        default:          return false
        }
    }

    /// Extra spacing (pts) between the target and the bubble, beyond the default
    /// gap. Lifts a bubble clear of a target whose own colour would camouflage the
    /// arrow — e.g. the accent-tinted "Read Article" button, against which the
    /// accent arrow disappears unless raised into the gap above it.
    var extraGap: CGFloat {
        switch self {
        case .readArticleLongPress: return 4
        default:                    return 0
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
