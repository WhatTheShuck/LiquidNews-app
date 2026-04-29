// IdentifiableURL.swift
// Wraps a URL with a stable Identifiable identity for use with .sheet(item:).

import Foundation

struct IdentifiableURL: Identifiable {
    let id: String
    let url: URL
    init(_ url: URL) { self.id = url.absoluteString; self.url = url }
}
