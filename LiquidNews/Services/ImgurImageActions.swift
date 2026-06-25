// ImgurImageActions.swift
// Downloads Imgur images to session-cached temp files, decodes UIImages, and
// (in Task 3) saves to Photos. Network is injected via DataFetch so the core is
// unit-testable with no real requests. Image URLs are pre-validated upstream by
// ImgurResolver (they come from ImgurContent.images), so there's no markup surface.

import UIKit
import Photos

enum ImgurImageActions {

    /// Injected network seam: returns the raw bytes for a URL, or nil on failure.
    typealias DataFetch = @Sendable (URL) async -> Data?

    /// Production fetch: shared URLSession; nil on non-2xx or transport error.
    static func defaultFetch(_ url: URL) async -> Data? {
        guard
            let (data, response) = try? await URLSession.shared.data(from: url),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else { return nil }
        return data
    }

    /// Session cache of in-flight/completed downloads, keyed by absoluteString, so
    /// concurrent calls for the same URL share one download (race-free) and repeat
    /// calls return the existing temp file without re-fetching.
    private actor FileCache {
        private var tasks: [String: Task<URL?, Never>] = [:]

        func file(for url: URL, fetch: @escaping DataFetch) -> Task<URL?, Never> {
            if let existing = tasks[url.absoluteString] { return existing }
            let task = Task<URL?, Never> { await ImgurImageActions.download(url, fetch: fetch) }
            tasks[url.absoluteString] = task
            return task
        }

        func invalidate(_ url: URL) { tasks[url.absoluteString] = nil }
    }

    private static let cache = FileCache()

    /// Downloads `url` and writes the bytes to a temp file; nil on download or write
    /// failure. The extension is derived from the URL path (default `jpg`).
    private static func download(_ url: URL, fetch: DataFetch) async -> URL? {
        guard let data = await fetch(url) else { return nil }
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        do {
            try data.write(to: dest)
            return dest
        } catch {
            return nil
        }
    }

    /// Returns a local temp-file URL for `url`, downloading once and caching for the
    /// session. A second call for the same URL returns the same file without re-fetching.
    static func localFile(for url: URL, fetch: @escaping DataFetch = defaultFetch) async -> URL? {
        let result = await cache.file(for: url, fetch: fetch).value
        // A failed download must not be cached as a permanent miss — allow a later retry.
        if result == nil { await cache.invalidate(url) }
        return result
    }

    /// Downloads `urls` concurrently and returns the successfully-written file URLs in
    /// input order, dropping failures.
    static func localFiles(for urls: [URL], fetch: @escaping DataFetch = defaultFetch) async -> [URL] {
        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask { (index, await localFile(for: url, fetch: fetch)) }
            }
            var indexed: [(Int, URL)] = []
            for await (index, file) in group {
                if let file { indexed.append((index, file)) }
            }
            return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// Decodes an image for Copy / Save. Returns nil on download or decode failure.
    static func image(for url: URL, fetch: DataFetch = defaultFetch) async -> UIImage? {
        guard let data = await fetch(url) else { return nil }
        return UIImage(data: data)
    }

    /// Saves `image` to the user's photo library. The first call triggers the system
    /// add-only permission prompt. Returns true on success. Requires
    /// NSPhotoLibraryAddUsageDescription in Info.plist.
    @MainActor
    static func saveToPhotos(_ image: UIImage) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
