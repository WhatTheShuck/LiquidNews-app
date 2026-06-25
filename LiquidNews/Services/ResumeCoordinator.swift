// ResumeCoordinator.swift
// Owns the launch-time "resume last story" decision so the one-shot and
// suppression logic is a unit-testable surface rather than ad-hoc state inside a
// view's onAppear. App-scoped @State, injected into the environment.

import Foundation
import Observation

/// The outcome of a launch resume evaluation.
enum ResumeDecision: Equatable {
    case none
    case banner(RecentStory)
    case autoOpen(id: Int)
}

@Observable
final class ResumeCoordinator {

    /// One-shot flag, scoped to the process launch: set true the first time a
    /// resume decision is made, never reset. Ensures resume fires at most once
    /// per launch — not on every Feed re-appearance.
    var launchResumeHandled = false

    /// Durable "this launch already opened something from a real deep link or
    /// Handoff" signal. Set by the URL/Handoff entry points the instant a
    /// pendingItemID is assigned — *before* it is consumed-and-nilled downstream,
    /// so suppression doesn't rely on the transient pendingItemID still being set
    /// by the time the Feed appears.
    var launchDeepLinkConsumed = false

    /// Called by the URL/Handoff entry points when they set a pendingItemID.
    func markDeepLinkConsumed() {
        launchDeepLinkConsumed = true
    }

    /// Pure decision over (mode, lastStory, launchResumeHandled,
    /// launchDeepLinkConsumed). Flips `launchResumeHandled` true on first call.
    func decide(mode: ResumeMode, lastStory: RecentStory?) -> ResumeDecision {
        guard !launchResumeHandled else { return .none }
        launchResumeHandled = true

        guard !launchDeepLinkConsumed else { return .none }

        switch mode {
        case .off:
            return .none
        case .prompt:
            guard let lastStory else { return .none }
            return .banner(lastStory)
        case .auto:
            guard let lastStory else { return .none }
            return .autoOpen(id: lastStory.id)
        }
    }
}
