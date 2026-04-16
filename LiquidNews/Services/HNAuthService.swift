// HNAuthService.swift
// Handles HackerNews session auth via the web login form.
//
// HN has no official auth API — we POST to the same HTML form the website uses
// and check for a `user` session cookie to determine if credentials are valid.
// The cookie is kept in the shared HTTPCookieStorage so future requests
// (votes, replies) are automatically authenticated.

import Foundation
import Observation

enum HNAuthError: LocalizedError {
    case invalidCredentials
    case actionFailed
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Incorrect username or password."
        case .actionFailed:       return "Action failed. You may not have permission or may have already performed this action."
        case .networkError(let e): return e.localizedDescription
        }
    }
}

@Observable
final class HNAuthService {

    static let shared = HNAuthService()

    private(set) var username: String?
    var isLoggedIn: Bool { username != nil }

    private let loginURL = URL(string: "https://news.ycombinator.com/login")!
    private let cookieStorage = HTTPCookieStorage.shared

    private enum Keys {
        static let username = "LN_username"
    }

    private init() {
        // Restore persisted username from a previous session.
        // We trust the cookie is still valid until a request proves otherwise.
        username = UserDefaults.standard.string(forKey: Keys.username)
    }

    // MARK: - Login

    func login(username: String, password: String) async throws {
        let body = "acct=\(username.hnEncoded)&pw=\(password.hnEncoded)&goto=news"
        guard let bodyData = body.data(using: .utf8) else {
            throw HNAuthError.invalidCredentials
        }

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        do {
            let (_, _) = try await URLSession.shared.data(for: request)

            // HN sets a `user` cookie on successful login.
            let hnBase = URL(string: "https://news.ycombinator.com")!
            let cookies = cookieStorage.cookies(for: hnBase) ?? []
            guard cookies.contains(where: { $0.name == "user" }) else {
                throw HNAuthError.invalidCredentials
            }

            self.username = username
            UserDefaults.standard.set(username, forKey: Keys.username)
        } catch let err as HNAuthError {
            throw err
        } catch {
            throw HNAuthError.networkError(error)
        }
    }

    // MARK: - Engagement actions

    /// Votes on an item. `how` is `"up"` to upvote or `"un"` to unvote.
    /// Downvote (`"down"`) requires sufficient karma and only works on comments.
    func vote(itemId: Int, how: String) async throws {
        let html = try await fetchItemPageHTML(itemId: itemId)
        guard let auth = parseVoteAuth(from: html, itemId: itemId, how: how) else {
            throw HNAuthError.actionFailed
        }
        let voteURL = URL(string: "https://news.ycombinator.com/vote?id=\(itemId)&how=\(how)&auth=\(auth)&goto=news")!
        let _ = try await hnRequest(url: voteURL)
    }

    /// Flags an item as inappropriate.
    func flag(itemId: Int) async throws {
        let html = try await fetchItemPageHTML(itemId: itemId)
        guard let auth = parseFlagAuth(from: html, itemId: itemId) else {
            throw HNAuthError.actionFailed
        }
        let flagURL = URL(string: "https://news.ycombinator.com/flag?id=\(itemId)&auth=\(auth)")!
        let _ = try await hnRequest(url: flagURL)
    }

    /// Posts a reply to an item. The session cookie provides authentication.
    func reply(parentId: Int, text: String) async throws {
        // HN's reply?id=X page returns an empty body for programmatic requests (bot protection).
        // Instead, fetch item?id=X — when logged in, HN embeds the reply form with the HMAC
        // directly in the item page, which works fine for authenticated scraping.
        let html = try await fetchItemPageHTML(itemId: parentId)
        guard let hmac = parseHmac(from: html) else {
            throw HNAuthError.actionFailed
        }

        let commentURL = URL(string: "https://news.ycombinator.com/comment")!
        var commentRequest = hnURLRequest(url: commentURL)
        commentRequest.httpMethod = "POST"
        commentRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let gotoParam = "item?id=\(parentId)".hnEncoded
        let body = "parent=\(parentId)&goto=\(gotoParam)&hmac=\(hmac)&text=\(text.hnEncoded)"
        commentRequest.httpBody = body.data(using: .utf8)
        var (responseData, postResponse) = try await URLSession.shared.data(for: commentRequest)
        var postHTML = String(data: responseData, encoding: .utf8) ?? ""

        // HN sometimes returns a "commconfirm" page requiring a second POST with a fresh HMAC.
        // The confirmation page contains a new /comment form — just re-submit it.
        if let responseURL = (postResponse as? HTTPURLResponse)?.url,
           responseURL.absoluteString.contains("commconfirm") {
            guard let confirmHmac = parseHmac(from: postHTML) else {
                throw HNAuthError.actionFailed
            }
            var confirmRequest = hnURLRequest(url: commentURL)
            confirmRequest.httpMethod = "POST"
            confirmRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let confirmBody = "parent=\(parentId)&goto=\(gotoParam)&hmac=\(confirmHmac)&text=\(text.hnEncoded)"
            confirmRequest.httpBody = confirmBody.data(using: .utf8)
            (responseData, postResponse) = try await URLSession.shared.data(for: confirmRequest)
            postHTML = String(data: responseData, encoding: .utf8) ?? ""
        }

        // If we still end up on a commconfirm or error page, surface it as a failure.
        if let finalURL = (postResponse as? HTTPURLResponse)?.url,
           finalURL.absoluteString.contains("commconfirm") || postHTML.contains("Unknown or expired") {
            throw HNAuthError.actionFailed
        }
    }

    // MARK: - Logout

    func logout() {
        let hnBase = URL(string: "https://news.ycombinator.com")!
        if let cookies = cookieStorage.cookies(for: hnBase) {
            for cookie in cookies { cookieStorage.deleteCookie(cookie) }
        }
        username = nil
        UserDefaults.standard.removeObject(forKey: Keys.username)
    }

    // MARK: - Private helpers

    /// Builds a URLRequest with User-Agent and the HN session cookie explicitly set.
    /// URLSession.shared can silently drop cookies from HTTPCookieStorage on iOS,
    /// so we inject the Cookie header directly to guarantee authentication.
    private func hnURLRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let hnBase = URL(string: "https://news.ycombinator.com")!
        let cookies = HTTPCookieStorage.shared.cookies(for: hnBase) ?? []
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        for (field, value) in cookieHeader {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    private func hnRequest(url: URL) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: hnURLRequest(url: url))
    }

    private func fetchItemPageHTML(itemId: Int) async throws -> String {
        let url = URL(string: "https://news.ycombinator.com/item?id=\(itemId)")!
        let (data, _) = try await hnRequest(url: url)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseVoteAuth(from html: String, itemId: Int, how: String) -> String? {
        // HN vote links appear as: vote?id=ITEMID&amp;how=DIRECTION&amp;auth=TOKEN
        for pattern in ["vote?id=\(itemId)&amp;how=\(how)&amp;auth=",
                        "vote?id=\(itemId)&how=\(how)&auth="] {
            if let range = html.range(of: pattern) {
                let token = String(html[range.upperBound...].prefix(while: { $0.isHexDigit }))
                if !token.isEmpty { return token }
            }
        }
        return nil
    }

    private func parseFlagAuth(from html: String, itemId: Int) -> String? {
        for pattern in ["flag?id=\(itemId)&amp;auth=",
                        "flag?id=\(itemId)&auth="] {
            if let range = html.range(of: pattern) {
                let token = String(html[range.upperBound...].prefix(while: { $0.isHexDigit }))
                if !token.isEmpty { return token }
            }
        }
        return nil
    }

    private func parseHmac(from html: String) -> String? {
        // HN uses unquoted attribute names: <input type=hidden name=hmac value="TOKEN">
        // Try patterns in order of likelihood.
        let patterns = [
            "name=hmac value=\"",
            "name=hmac value='",
            "name=hmac value=",
            "name=\"hmac\" value=\"",
            "name='hmac' value='",
        ]
        for pattern in patterns {
            if let range = html.range(of: pattern) {
                let after = html[range.upperBound...]
                let hmac = String(after.prefix(while: { $0 != "\"" && $0 != "'" && $0 != ">" && !$0.isWhitespace }))
                if !hmac.isEmpty { return hmac }
            }
        }
        return nil
    }
}

// MARK: - Helpers

private extension String {
    /// Percent-encodes the string for inclusion in an x-www-form-urlencoded body.
    var hnEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
