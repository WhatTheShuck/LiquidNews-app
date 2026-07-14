// FeedEntrance.swift
// Entrance animation for feed story cards.
//
// Replay policy: cards animate on load events only (initial load, category
// switch, pull-to-refresh) — never when rows are merely realised by scrolling
// or appended by pagination. The coordinator tracks a "load generation": the
// view model opens one whenever it repopulates the feed wholesale, and a row
// animates only if it first appears within a short window of that moment and
// hasn't animated yet this generation. Rows recycled by scrolling away and
// back never replay; paginated rows are pre-marked settled so a page landing
// inside the window stays out of the cascade.

import SwiftUI

// MARK: - Coordinator

/// Decides whether a feed row should animate its entrance, and with what
/// stagger delay. Pure timing/bookkeeping — the *style* of the animation is
/// the view's concern (it has environment access for Reduce Motion).
@Observable
final class FeedEntranceCoordinator {

    /// Rows first appearing later than this after a load event don't animate —
    /// they were realised by scrolling, not by the load.
    static let window: TimeInterval = 1.5
    /// Per-index cascade spacing. Slow enough that the top-to-bottom wave is
    /// perceptible as a sequence rather than a flicker.
    static let staggerStep: TimeInterval = 0.14
    /// Index at which the cascade delay stops growing.
    static let staggerCap = 8

    private var generationStart: Date = .distantPast
    private var animatedIDs: Set<Int> = []

    /// Opens a new load generation: every row becomes eligible to animate
    /// again for the next `window` seconds.
    func beginGeneration(now: Date = .now) {
        generationStart = now
        animatedIDs.removeAll()
    }

    /// Returns the stagger delay for a row's entrance, or nil when the row
    /// should appear instantly. Marks the ID as animated on success, so each
    /// row animates at most once per generation.
    func entranceDelay(id: Int, index: Int, now: Date = .now) -> TimeInterval? {
        guard now.timeIntervalSince(generationStart) < Self.window,
              !animatedIDs.contains(id) else { return nil }
        animatedIDs.insert(id)
        return Double(min(index, Self.staggerCap)) * Self.staggerStep
    }

    /// Excludes IDs from the entrance cascade even inside the window.
    /// Pagination appends are never load events, but a fast page 2 can land
    /// while the window from the initial load is still open — the view model
    /// marks appended rows before inserting them.
    func markSettled(_ ids: some Sequence<Int>) {
        animatedIDs.formUnion(ids)
    }
}

// MARK: - Style definitions

/// The card's starting pose for a style; it animates from here to identity.
private struct EntranceStart {
    var opacity: Double = 1
    var offsetY: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var anchor: UnitPoint = .center
    var blur: CGFloat = 0
}

private extension FeedEntranceStyle {

    /// nil for `.off`: the card renders at identity even before it settles.
    var entranceStart: EntranceStart? {
        switch self {
        case .off:
            return nil
        case .fade:
            return EntranceStart(opacity: 0, offsetY: 8)
        case .drip:
            // Hanging-droplet pose: elongated and above its slot, anchored to
            // its bottom edge so the landing compresses onto the resting point.
            // The bouncy spring drops it in and overshoots — a visible squash
            // on landing, then a wobble to rest. The overshoot is the liquid.
            // The row's top-edge mask (below) occludes everything above the
            // slot, so the card reads as sliding out from under the card above.
            return EntranceStart(opacity: 0, offsetY: -28, scaleX: 0.92, scaleY: 1.18, anchor: .bottom)
        case .condense:
            // Blurred and slightly oversized, sharpening into focus.
            return EntranceStart(opacity: 0, scaleX: 1.06, scaleY: 1.06, blur: 12)
        }
    }

    var entranceAnimation: Animation {
        switch self {
        case .off:      return .default
        case .fade:     return .easeOut(duration: 0.35)
        case .drip:     return .spring(duration: 0.95, bounce: 0.6)
        case .condense: return .easeOut(duration: 0.4)
        }
    }

    /// Animation for the opacity reveal, where it differs from the motion.
    /// Drip fades in fast on a non-bouncy curve so the card is opaque while
    /// it falls and lands — leaving opacity on the bouncy spring keeps the
    /// card half-transparent through exactly the motion it should be showing.
    var revealAnimation: Animation {
        switch self {
        case .drip: return .easeOut(duration: 0.3)
        default:    return entranceAnimation
        }
    }
}

// MARK: - Modifier

/// Animates a feed row's first appearance for the current load generation.
/// Deliberately driven by per-row local state in `.onAppear` rather than
/// insertion transitions: a transaction in flight while the lazy list realises
/// cells makes them fly in from the top (see CommentView.autoLoadIfNeeded).
private struct FeedEntranceModifier: ViewModifier {
    let coordinator: FeedEntranceCoordinator
    let itemID: Int
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settings = UserSettings.shared

    /// False until this row's entrance has resolved (animated or skipped).
    /// Rows render in their style's starting pose for the pre-`onAppear`
    /// frame; rows that turn out not to animate settle before display.
    @State private var settled = false

    /// The stagger delay granted by the coordinator, kept so the scoped
    /// opacity reveal in `body` carries the same delay as the motion spring.
    @State private var grantedDelay: TimeInterval = 0

    /// Reduce Motion degrades the moving styles to a plain crossfade;
    /// off stays off.
    private var effectiveStyle: FeedEntranceStyle {
        let style = settings.feedEntranceStyle
        guard style != .off else { return .off }
        return reduceMotion ? .fade : style
    }

    func body(content: Content) -> some View {
        let start = settled ? nil : effectiveStyle.entranceStart
        content
            // Opacity is scoped to its own reveal curve: the motion spring is
            // bouncy, and fading along it would keep the card half-transparent
            // through the fall and landing it is supposed to be showing.
            .animation(effectiveStyle.revealAnimation.delay(grantedDelay)) {
                $0.opacity(start?.opacity ?? 1)
            }
            .scaleEffect(
                x: start?.scaleX ?? 1,
                y: start?.scaleY ?? 1,
                anchor: start?.anchor ?? .center
            )
            .offset(y: start?.offsetY ?? 0)
            .blur(radius: start?.blur ?? 0)
            // Stationary top-edge fade, applied after the offset so the card
            // slides beneath it: alpha ramps from 1 at the slot's top edge to
            // 0 over the 18pt above it, so a falling card dissolves softly as
            // it pokes above its slot instead of showing a hard clipped edge
            // (a flat cut across the card's glass border reads as a rendering
            // bug, especially in dark mode). The mask's hard boundary sits
            // exactly where alpha reaches zero, so no cut is ever visible.
            // Open on the other three sides so it never clips shadows or the
            // landing squash. Kept permanently: conditioning it on `settled`
            // would drop it the instant the animation *starts* (the flag flips
            // at animation begin, not end); a settled card sits fully inside
            // the opaque region, where the mask is a no-op.
            .mask {
                Rectangle()
                    .padding(.horizontal, -64)
                    .padding(.bottom, -64)
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 18)
                            .padding(.horizontal, -64)
                            .offset(y: -18)
                    }
            }
            .onAppear {
                guard !settled else { return }
                let style = effectiveStyle
                guard style != .off,
                      let delay = coordinator.entranceDelay(id: itemID, index: index) else {
                    settled = true
                    return
                }
                grantedDelay = delay
                // Deferred one runloop turn: flipping `settled` here directly
                // coalesces into the row's first committed frame (onAppear runs
                // inside the same update that inserts the row), so the entrance
                // never renders — cards pop in at identity. After the start pose
                // has actually been committed, the flip animates from it.
                Task { @MainActor in
                    guard !settled else { return }
                    withAnimation(style.entranceAnimation.delay(delay)) {
                        settled = true
                    }
                }
            }
    }
}

extension View {
    /// Entrance animation for a feed story card. `index` is the card's
    /// position in the visible list (drives the cascade stagger).
    func feedEntrance(_ coordinator: FeedEntranceCoordinator, id: Int, index: Int) -> some View {
        modifier(FeedEntranceModifier(coordinator: coordinator, itemID: id, index: index))
    }
}
