// ResumeBannerView.swift
// The "continue reading" card at the top of the feed. Renders only when a local
// primary exists. The primary (hero) row is always this device's last story; an
// optional subordinate hint row offers a different story last opened on another
// device (resolved via ResumeResolver). Signature styling: a vertical accent
// "thread bar" on the leading edge, reusing the comment thread-line motif.

import SwiftUI

// MARK: - Presentation model

/// One resumable story, already resolved to display-ready fields so the banner
/// renders with no fetch.
struct ResumeEntry: Identifiable, Equatable {
    let id: Int
    let title: String
    let savedAt: Date
    /// True when this is the story last opened on the current device.
    let isThisDevice: Bool
    /// Human label for origin, e.g. "iPhone" or "iPad".
    let deviceName: String
    /// SF Symbol for the originating device.
    let deviceSymbol: String
}

// MARK: - Banner

struct ResumeBannerView: View {
    /// This device's last story — always present (no local ⇒ no banner).
    let primary: ResumeEntry
    /// A different story from another device, when one qualifies.
    let hint: ResumeEntry?

    /// Open the given story id (drives the existing deep-link path).
    let onOpen: (Int) -> Void
    /// Dismiss the banner for this launch.
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onOpen(primary.id)
            } label: {
                primaryRow(primary)
            }
            .buttonStyle(.plain)

            if let hint {
                Divider()
                    .overlay(AppTheme.glassBorder)
                    .padding(.leading, 18)
                Button {
                    onOpen(hint.id)
                } label: {
                    hintRow(hint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .glassCard(tint: AppTheme.accent)
        .overlay(alignment: .topTrailing) { dismissButton }
    }

    /// The hero "continue reading" row.
    private func primaryRow(_ entry: ResumeEntry) -> some View {
        HStack(spacing: 14) {
            threadBar
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("CONTINUE READING")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(AppTheme.accent)
                    Text("· \(relativeTime(entry.savedAt))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text(entry.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.forward.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    /// The small subordinate "also reading elsewhere" hint.
    private func hintRow(_ entry: ResumeEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.deviceSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("On \(entry.deviceName)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text("· \(entry.title)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    // MARK: Shared pieces

    /// The signature accent "thread" bar — your reading thread, continued.
    private var threadBar: some View {
        Capsule()
            .fill(AppTheme.accent)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: .now)
    }
}

// MARK: - Preview

private let samplePrimary = ResumeEntry(
    id: 1, title: "Show HN: I built a SQLite-backed feed reader in a weekend",
    savedAt: Date().addingTimeInterval(-540), isThisDevice: true,
    deviceName: "iPhone", deviceSymbol: "iphone"
)
private let sampleHint = ResumeEntry(
    id: 2, title: "The hidden cost of microservices nobody talks about",
    savedAt: Date().addingTimeInterval(-7200), isThisDevice: false,
    deviceName: "iPad", deviceSymbol: "ipad"
)

#Preview("Primary + hint") {
    ZStack {
        AppTheme.backgroundGradient(for: .dark).ignoresSafeArea()
        ResumeBannerView(primary: samplePrimary, hint: sampleHint,
                         onOpen: { _ in }, onDismiss: {})
            .padding()
    }
}

#Preview("Primary only") {
    ZStack {
        AppTheme.backgroundGradient(for: .light).ignoresSafeArea()
        ResumeBannerView(primary: samplePrimary, hint: nil,
                         onOpen: { _ in }, onDismiss: {})
            .padding()
    }
}
