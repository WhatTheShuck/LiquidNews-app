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

    /// Convenience: no-op when `mark` is nil (so a target can opt out conditionally).
    @ViewBuilder
    func coachMarkTarget(_ mark: CoachMark?) -> some View {
        if let mark { coachMarkTarget(mark) } else { self }
    }
}

// MARK: - Bubble

struct CoachMarkBubble: View {
    let text: String
    let arrowEdge: Edge
    let targetRect: CGRect
    var isSwipeHint: Bool = false
    var extraGap: CGFloat = 0
    let onDismiss: () -> Void

    /// Gap between the target and the bubble's arrow tip.
    private let baseGap: CGFloat = 10
    private var gap: CGFloat { baseGap + extraGap }
    private let maxWidth: CGFloat = 240

    /// Measured card size — needed to position the bubble by its edge (fully clear
    /// of the target) rather than by its center, which would overlap the target and
    /// hide the arrow behind it.
    @State private var bubbleSize: CGSize = .zero

    var body: some View {
        bubble
            .frame(maxWidth: maxWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { bubbleSize = $0 }
            .position(bubbleAnchorPoint)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .task {
                // Auto-fade after ~5s if the user doesn't act.
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled { onDismiss() }
            }
    }

    private var bubble: some View {
        bubbleContent
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 16, tint: AppTheme.accent)
            .overlay(alignment: arrowAlignment) {
                // Swipe hints communicate direction with the inline chevrons, so
                // they skip the single pointing triangle.
                if !isSwipeHint {
                    ArrowTriangle(edge: arrowEdge)
                        .fill(AppTheme.accent.opacity(0.45))
                        .frame(width: 16, height: 9)
                        .offset(arrowOffset)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isSwipeHint {
            HStack(spacing: 10) {
                SwipeChevrons(edge: .leading)
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                SwipeChevrons(edge: .trailing)
            }
        } else {
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
    }

    /// Center point for `.position`, derived so the bubble's *edge* (not its center)
    /// sits `gap` away from the target — keeping the whole card, and its arrow, clear
    /// of the target instead of overlapping it.
    private var bubbleAnchorPoint: CGPoint {
        let halfW = bubbleSize.width / 2
        let halfH = bubbleSize.height / 2
        switch arrowEdge {
        case .bottom: return CGPoint(x: targetRect.midX, y: targetRect.minY - gap - halfH)   // fully above
        case .top:    return CGPoint(x: targetRect.midX, y: targetRect.maxY + gap + halfH)    // fully below
        case .leading: return CGPoint(x: targetRect.maxX + gap + halfW, y: targetRect.midY)   // fully right
        case .trailing: return CGPoint(x: targetRect.minX - gap - halfW, y: targetRect.midY)  // fully left
        }
    }

    private var arrowAlignment: Alignment {
        switch arrowEdge {
        case .bottom: return .bottom
        case .top:    return .top
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    private var arrowOffset: CGSize {
        switch arrowEdge {
        case .bottom: return CGSize(width: 0, height: 9)
        case .top:    return CGSize(width: 0, height: -9)
        case .leading: return CGSize(width: -9, height: 0)
        case .trailing: return CGSize(width: 9, height: 0)
        }
    }
}

// MARK: - Screen modifier

private struct CoachMarksModifier: ViewModifier {
    let marks: [CoachMark]
    var isSuppressed: Bool

    private let store = CoachMarkStore.shared
    @State private var controller = CoachMarkController()
    /// One hint per screen visit. Latched on the first dismissal; reset when the
    /// screen reappears (a sheet host is rebuilt per presentation, giving fresh
    /// @State — so the second mark on a screen only appears on a later visit).
    @State private var shownThisVisit = false
    @State private var activeMark: CoachMark?

    func body(content: Content) -> some View {
        content
            .environment(controller)
            .overlayPreferenceValue(CoachMarkAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    ZStack {
                        if let mark = activeMark, let anchor = anchors[mark] {
                            CoachMarkBubble(
                                text: mark.text,
                                arrowEdge: mark.arrowEdge,
                                targetRect: proxy[anchor],
                                isSwipeHint: mark.isSwipeHint,
                                extraGap: mark.extraGap
                            ) {
                                dismiss(mark)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: activeMark)
                    .onAppear { activate(anchored: Set(anchors.keys)) }
                    .onChange(of: Set(anchors.keys)) { _, present in
                        activate(anchored: present)
                    }
                }
                // Only the bubble itself is interactive; the rest of the overlay
                // never intercepts touches meant for the screen below.
                .allowsHitTesting(activeMark != nil)
            }
            .onChange(of: controller.interacted) { _, fired in
                if let mark = activeMark, fired.contains(mark) { dismiss(mark) }
            }
    }

    private func activate(anchored: Set<CoachMark>) {
        guard !isSuppressed, !shownThisVisit, activeMark == nil else { return }
        activeMark = firstEligibleCoachMark(
            in: marks, seen: store.seenMarks(), anchored: anchored)
    }

    private func dismiss(_ mark: CoachMark) {
        store.markSeen(mark)
        shownThisVisit = true     // no further marks this visit
        activeMark = nil
    }
}

extension View {
    /// Renders at most one eligible coach mark from `marks` at this screen root.
    /// Pass `isSuppressed: true` to defer while a sheet/presentation is active.
    func coachMarks(_ marks: [CoachMark], isSuppressed: Bool = false) -> some View {
        modifier(CoachMarksModifier(marks: marks, isSuppressed: isSuppressed))
    }
}

/// A pair of double chevrons that gently pulse outward to suggest a horizontal
/// swipe. `edge` is the direction the chevrons point (.leading or .trailing).
private struct SwipeChevrons: View {
    let edge: Edge
    @State private var nudge = false

    var body: some View {
        Image(systemName: edge == .leading ? "chevron.compact.left" : "chevron.compact.right")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppTheme.accent)
            .offset(x: nudge ? (edge == .leading ? -3 : 3) : 0)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: nudge)
            .onAppear { nudge = true }
    }
}

/// A small triangle pointing outward from `edge`.
private struct ArrowTriangle: Shape {
    let edge: Edge

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch edge {
        case .bottom: // points down
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        case .top: // points up
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        case .leading: // points left
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        case .trailing: // points right
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
        p.closeSubpath()
        return p
    }
}
