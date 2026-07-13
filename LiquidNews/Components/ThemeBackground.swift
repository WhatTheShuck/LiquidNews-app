// ThemeBackground.swift
// The app's screen background: renders the user's custom background override
// (photo with dim/blur scrim, solid colour, or gradient) when set, otherwise
// the active theme preset's gradient. Drop-in replacement for
// `AppTheme.backgroundGradient(for:)` at screen-background callsites.

import SwiftUI

struct ThemeBackground: View {

    @Environment(\.colorScheme) private var environmentScheme
    @State private var settings = UserSettings.shared

    /// Explicit scheme for previews/components that pin light or dark.
    private let explicitScheme: ColorScheme?

    init(colorScheme: ColorScheme? = nil) {
        self.explicitScheme = colorScheme
    }

    private var scheme: ColorScheme { explicitScheme ?? environmentScheme }

    var body: some View {
        switch settings.customBackgroundKind {
        case .image:
            if let revision = settings.customBackgroundImageRevision,
               let image = CustomBackgroundStore.cachedImage(revision: revision) {
                photoBackground(image)
            } else {
                presetGradient
            }
        case .solid:
            if settings.customBackgroundHexes.count == 1,
               let color = Color(hexString: settings.customBackgroundHexes[0]) {
                color
            } else {
                presetGradient
            }
        case .gradient:
            if let stops = Self.gradientStops(from: settings.customBackgroundHexes) {
                LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                presetGradient
            }
        case .none:
            presetGradient
        }
    }

    private func photoBackground(_ image: UIImage) -> some View {
        GeometryReader { proxy in
            let blur = settings.customBackgroundBlur
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .blur(radius: blur)
                // Blur samples past the image edge and would leave a soft
                // vignette; slight overscale pushes it off-screen.
                .scaleEffect(blur > 0 ? 1 + blur / 100 : 1)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay(
                    // Mixing toward glassTint (not swatchColor) keeps the
                    // light-mode scrim's job intact: white toward a pale theme
                    // colour still lightens the photo for dark-text legibility.
                    (scheme == .dark ? Color.black : Color.white)
                        .mix(with: settings.selectedAppTheme.glassTint(for: scheme), by: 0.3)
                        .opacity(settings.customBackgroundDim)
                )
        }
    }

    private var presetGradient: LinearGradient {
        AppTheme.backgroundGradient(for: scheme)
    }

    /// Maps 2–3 hex strings to gradient stops laid out like the presets
    /// (2 → 0/1, 3 → 0/0.5/1). Nil when the count is out of range or any hex
    /// fails to parse — callers fall back to the preset gradient.
    static func gradientStops(from hexes: [String]) -> [Gradient.Stop]? {
        guard (2...3).contains(hexes.count) else { return nil }
        let colors = hexes.compactMap(Color.init(hexString:))
        guard colors.count == hexes.count else { return nil }
        let locations: [CGFloat] = colors.count == 2 ? [0, 1] : [0, 0.5, 1]
        return zip(colors, locations).map { Gradient.Stop(color: $0, location: $1) }
    }
}

#Preview("Preset fallback") {
    ThemeBackground().ignoresSafeArea()
}
