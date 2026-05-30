// AppIconSyncer.swift
// Workaround for iOS 26 / Xcode 26 limitation: alternate app icons backed by
// .icon (Icon Composer) files do not resolve dark-mode variants through the
// asset catalog the way primary icons do. We ship a separate `AppIconAltDark`
// alternate entry with its own loose PNGs and swap between AppIconAlt and
// AppIconAltDark at runtime based on the system appearance.

import SwiftUI
import UIKit

enum AppIconFamily: String {
    case `default`
    case letter

    static func from(alternateIconName name: String?) -> AppIconFamily {
        switch name {
        case "AppIconAlt", "AppIconAltDark": .letter
        default: .default
        }
    }

    func resolvedAlternateIconName(isDark: Bool) -> String? {
        switch self {
        case .default: nil
        case .letter:  isDark ? "AppIconAltDark" : "AppIconAlt"
        }
    }
}

enum AppIconStorage {
    static let familyKey = "LN_iconFamily"
}

@MainActor
func applyAppIcon(family: AppIconFamily, isDark: Bool) {
    let target = family.resolvedAlternateIconName(isDark: isDark)
    guard UIApplication.shared.alternateIconName != target else { return }
    UIApplication.shared.setAlternateIconName(target) { error in
        if let error { print("[AppIcon] setAlternateIconName failed: \(error)") }
    }
}

/// Hidden view that keeps the alternate icon in sync with the system appearance
/// whenever the user has the `letter` family selected. Mount once from the app's
/// WindowGroup as a `.background(AppIconSyncer())`.
struct AppIconSyncer: View {
    @AppStorage(AppIconStorage.familyKey) private var familyRaw: String = AppIconFamily.default.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: colorScheme, initial: true) { _, newScheme in
                let family = AppIconFamily(rawValue: familyRaw) ?? .default
                applyAppIcon(family: family, isDark: newScheme == .dark)
            }
            .onChange(of: familyRaw) { _, newRaw in
                let family = AppIconFamily(rawValue: newRaw) ?? .default
                applyAppIcon(family: family, isDark: colorScheme == .dark)
            }
    }
}
