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
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Incorrect username or password."
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

    // MARK: - Logout

    func logout() {
        let hnBase = URL(string: "https://news.ycombinator.com")!
        if let cookies = cookieStorage.cookies(for: hnBase) {
            for cookie in cookies { cookieStorage.deleteCookie(cookie) }
        }
        username = nil
        UserDefaults.standard.removeObject(forKey: Keys.username)
    }
}

// MARK: - Helpers

private extension String {
    /// Percent-encodes the string for inclusion in an x-www-form-urlencoded body.
    var hnEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
