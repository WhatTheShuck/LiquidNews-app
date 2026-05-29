// HNURLRouter.swift
// Detects HN thread URLs and routes them according to the user's hnThreadLinkOpen setting.

import UIKit

enum HNURLRouter {

    static func isHNItemURL(_ url: URL) -> Bool {
        guard url.host?.hasSuffix("ycombinator.com") == true,
              url.path == "/item",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.queryItems?.first(where: { $0.name == "id" })?.value != nil
        else { return false }
        return true
    }

    static func itemID(from url: URL) -> Int? {
        guard isHNItemURL(url),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "id" })?.value
        else { return nil }
        return Int(value)
    }

    @MainActor
    static func handle(_ url: URL, deepLink: DeepLinkState, overrideMode: HNLinkMode? = nil) {
        guard isHNItemURL(url) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let mode = overrideMode ?? UserSettings.shared.hnThreadLinkOpen
        switch mode {
        case .inApp:
            guard let id = itemID(from: url) else { return }
            deepLink.pendingItemID = id
        case .safari:
            UIApplication.shared.open(url)
        case .ask:
            presentShareSheet(for: url)
        }
    }

    // ShareSheet.swift (UIViewControllerRepresentable) can't be used here because
    // this router is called from static context with no SwiftUI view hierarchy.
    @MainActor
    static func presentShareSheet(for url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.keyWindow?.rootViewController
        else { return }

        var top = root
        while let presented = top.presentedViewController { top = presented }

        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        top.present(activity, animated: true)
    }
}
