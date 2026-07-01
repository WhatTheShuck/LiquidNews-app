// LinkOpenMode.swift
// One home for link-open routing modes. The three near-identical per-context enums
// — feed article (`LinkOpenMode`), comment link (`CommentLinkMode`), and reader inline
// link (`ReaderLinkMode`) — keep their own case sets (each context allows a different
// subset) but derive ALL user-facing copy from a single `LinkDestination`, so the
// label/icon/subtitle text lives in exactly one place instead of being triplicated.
//
// HN thread links use the separate `HNLinkMode`: its destinations (in-app item view /
// Safari / ask) don't map onto `LinkDestination`, and it already has its own router
// (`HNURLRouter`). Per-surface *routing* stays in each view because a tapped link lands
// in a different container per surface (a sheet, the iPad detail column, or inline web
// navigation) — only the shared vocabulary and display copy are centralised here.

import Foundation

// MARK: - Canonical destination

/// The distinct ways a tapped link can open. Every per-context mode enum maps its
/// cases onto these, and all user-facing copy is defined here — the single source of
/// truth that removes the old per-enum label/subtitle/icon boilerplate.
enum LinkDestination {
    case reader
    case inAppSafari
    case inline
    case safari

    var label: String {
        switch self {
        case .reader:      "Reader"
        case .inAppSafari: "In-App Safari"
        case .inline:      "Inline"
        case .safari:      "Safari"
        }
    }

    var subtitle: String {
        switch self {
        case .reader:      "Extract and display content natively"
        case .inAppSafari: "Open in Safari without leaving the app"
        case .inline:      "Navigate within the current view"
        case .safari:      "Hand off to Safari"
        }
    }

    var systemImage: String {
        switch self {
        case .reader:      "textformat"
        case .inAppSafari: "safari"
        case .inline:      "arrow.turn.down.right"
        case .safari:      "arrow.up.right.square"
        }
    }
}

// MARK: - Shared mode surface

/// Shared surface for the per-context link-open mode enums. Each conformer declares the
/// case subset its context allows and maps every case to a `LinkDestination`; the
/// display metadata (`id`/`label`/`subtitle`/`systemImage`) is then derived once here.
protocol LinkOpenModeProtocol: RawRepresentable, CaseIterable, Identifiable where RawValue == String {
    var destination: LinkDestination { get }
}

extension LinkOpenModeProtocol {
    var id: String { rawValue }
    var label: String { destination.label }
    var subtitle: String { destination.subtitle }
    var systemImage: String { destination.systemImage }
}

// MARK: - Per-context modes

/// How a feed story's article link opens.
enum LinkOpenMode: String, CaseIterable, Identifiable, LinkOpenModeProtocol {
    case reader      = "reader"
    case inAppSafari = "inAppSafari"
    case safari      = "safari"

    var destination: LinkDestination {
        switch self {
        case .reader:      .reader
        case .inAppSafari: .inAppSafari
        case .safari:      .safari
        }
    }
}

/// How a link tapped inside a comment opens.
enum CommentLinkMode: String, CaseIterable, Identifiable, LinkOpenModeProtocol {
    case inAppSafari = "inAppSafari"
    case reader      = "reader"
    case safari      = "safari"

    var destination: LinkDestination {
        switch self {
        case .inAppSafari: .inAppSafari
        case .reader:      .reader
        case .safari:      .safari
        }
    }
}

/// How a link tapped inside the native reader opens. Adds `.inline` (navigate within
/// the current reader web view) to the shared destinations.
enum ReaderLinkMode: String, CaseIterable, Identifiable, LinkOpenModeProtocol {
    case inAppSafari = "inAppSafari"
    case reader      = "reader"
    case inline      = "inline"
    case safari      = "safari"

    var destination: LinkDestination {
        switch self {
        case .inAppSafari: .inAppSafari
        case .reader:      .reader
        case .inline:      .inline
        case .safari:      .safari
        }
    }
}

// MARK: - HN thread link mode

/// How an HN thread (`item?id=`) link opens. Distinct from the article-link modes:
/// its destinations don't map onto `LinkDestination`, and routing lives in `HNURLRouter`.
enum HNLinkMode: String, CaseIterable, Identifiable {
    case inApp   = "inApp"
    case safari  = "safari"
    case ask     = "ask"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inApp:   "In App"
        case .safari:  "Safari"
        case .ask:     "Ask Each Time"
        }
    }

    var subtitle: String {
        switch self {
        case .inApp:   "Open HN thread links within LiquidNews"
        case .safari:  "Hand off to Safari"
        case .ask:     "Show share sheet each time"
        }
    }

    var systemImage: String {
        switch self {
        case .inApp:   "apps.iphone"
        case .safari:  "arrow.up.right.square"
        case .ask:     "square.and.arrow.up"
        }
    }
}
