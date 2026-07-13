// CustomBackgroundStore.swift
// Manages the custom background image file. The binary lives in Application
// Support and never enters iCloud KVS (1 MB cap): settings sync across
// devices, the photo does not, so a device missing the file renders the
// preset gradient instead.

import UIKit

enum CustomBackgroundStore {

    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomBackground.jpg")
    }

    /// Longest edge the stored image is downscaled to, in pixels.
    @MainActor
    static var maxPixelEdge: CGFloat {
        let screen = UIScreen.main
        return max(screen.bounds.width, screen.bounds.height) * screen.scale
    }

    /// Returns the image scaled so its longest pixel edge is at most
    /// `maxPixelEdge`, preserving aspect ratio. Smaller images pass through.
    static func downscaled(_ image: UIImage, maxPixelEdge: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxPixelEdge else { return image }

        let ratio = maxPixelEdge / longest
        let targetSize = CGSize(width: (pixelWidth * ratio).rounded(.down),
                                height: (pixelHeight * ratio).rounded(.down))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1  // target size is already in pixels
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Downscales, JPEG-encodes, and atomically writes the image. A failed
    /// write throws and leaves any previous file untouched.
    static func save(_ image: UIImage, maxPixelEdge: CGFloat) throws {
        let scaled = downscaled(image, maxPixelEdge: maxPixelEdge)
        guard let data = scaled.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    @MainActor
    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
        cache = nil
    }

    // MARK: Decode cache

    /// One decoded image shared by every screen, keyed on the revision token
    /// so a new photo pick busts it without file-date checks.
    @MainActor
    private static var cache: (revision: String, image: UIImage)?

    /// Returns the decoded background image, or nil when the file is missing
    /// or undecodable (callers fall back to the preset gradient).
    @MainActor
    static func cachedImage(revision: String) -> UIImage? {
        if let cache, cache.revision == revision { return cache.image }
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return nil }
        cache = (revision, image)
        return image
    }
}
