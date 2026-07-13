// CustomBackgroundTests.swift
// Covers CustomBackgroundStore image handling and ThemeBackground's
// gradient-stop mapping.

import XCTest
import SwiftUI
@testable import LiquidNews

final class CustomBackgroundTests: XCTestCase {

    override func tearDown() async throws {
        await CustomBackgroundStore.delete()
    }

    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    // MARK: Downscale

    func testDownscaleCapsLongestEdge() {
        let scaled = CustomBackgroundStore.downscaled(makeImage(width: 8000, height: 4000), maxPixelEdge: 2000)
        let longest = max(scaled.size.width * scaled.scale, scaled.size.height * scaled.scale)
        XCTAssertEqual(longest, 2000, accuracy: 2)
        XCTAssertEqual(scaled.size.width / scaled.size.height, 2, accuracy: 0.01)
    }

    func testDownscaleLeavesSmallImagesAlone() {
        let image = makeImage(width: 100, height: 50)
        let scaled = CustomBackgroundStore.downscaled(image, maxPixelEdge: 2000)
        XCTAssertEqual(scaled.size, image.size)
    }

    // MARK: Save / load / delete

    func testSaveLoadDeleteRoundTrip() async throws {
        try CustomBackgroundStore.save(makeImage(width: 300, height: 200), maxPixelEdge: 2000)
        let loaded = await CustomBackgroundStore.cachedImage(revision: "rev-1")
        XCTAssertNotNil(loaded)

        await CustomBackgroundStore.delete()
        let afterDelete = await CustomBackgroundStore.cachedImage(revision: "rev-2")
        XCTAssertNil(afterDelete)
    }

    func testNewRevisionReloadsOverwrittenFile() async throws {
        try CustomBackgroundStore.save(makeImage(width: 300, height: 300), maxPixelEdge: 2000)
        _ = await CustomBackgroundStore.cachedImage(revision: "rev-1")

        try CustomBackgroundStore.save(makeImage(width: 400, height: 200), maxPixelEdge: 2000)
        let updated = await CustomBackgroundStore.cachedImage(revision: "rev-2")
        XCTAssertEqual(updated.map { $0.size.width / $0.size.height } ?? 0, 2, accuracy: 0.01)
    }

    func testMissingFileReturnsNil() async {
        await CustomBackgroundStore.delete()
        let image = await CustomBackgroundStore.cachedImage(revision: "rev-none")
        XCTAssertNil(image)
    }

    // MARK: ThemeBackground.gradientStops

    func testGradientStopsTwoColors() {
        let stops = ThemeBackground.gradientStops(from: ["ff0000", "0000ff"])
        XCTAssertEqual(stops?.map(\.location), [0, 1])
    }

    func testGradientStopsThreeColors() {
        let stops = ThemeBackground.gradientStops(from: ["ff0000", "00ff00", "0000ff"])
        XCTAssertEqual(stops?.map(\.location), [0, 0.5, 1])
    }

    func testGradientStopsRejectsBadInput() {
        XCTAssertNil(ThemeBackground.gradientStops(from: []))
        XCTAssertNil(ThemeBackground.gradientStops(from: ["ff0000"]))                                  // solid is not a gradient
        XCTAssertNil(ThemeBackground.gradientStops(from: ["zzzzzz", "0000ff"]))                        // invalid hex
        XCTAssertNil(ThemeBackground.gradientStops(from: ["ff0000", "00ff00", "0000ff", "ffffff"]))    // too many
    }

    // MARK: AppThemePreset.glassTint

    func testGlassTintDarkReturnsSwatch() {
        XCTAssertEqual(AppThemePreset.standard.glassTint(for: .dark),
                       AppThemePreset.standard.swatchColor)
        XCTAssertEqual(AppThemePreset.midnight.glassTint(for: .dark), Color.black)
    }

    func testGlassTintLightReturnsLightGradientFinalStop() {
        XCTAssertEqual(AppThemePreset.standard.glassTint(for: .light),
                       Color(red: 0.68, green: 0.81, blue: 1.00))
        XCTAssertEqual(AppThemePreset.gruvbox.glassTint(for: .light),
                       Color(red: 0.84, green: 0.77, blue: 0.63))
    }

    // MARK: GlassCardModifier.effectiveTint

    func testEffectiveTintExplicitWins() {
        XCTAssertEqual(
            GlassCardModifier.effectiveTint(explicit: .red, accent: .blue),
            .red)
        XCTAssertEqual(
            GlassCardModifier.effectiveTint(explicit: .clear, accent: .blue),
            .clear, "explicit .clear must win so opted-out cards stay neutral")
    }

    func testEffectiveTintDefaultsToAccent() {
        XCTAssertEqual(
            GlassCardModifier.effectiveTint(explicit: nil, accent: .blue),
            .blue)
    }
}
