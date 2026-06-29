// FeatureCard.swift
// One feature row — icon + title + body on a glass card. Shared by
// OnboardingView (first launch) and WhatsNewView (version-gated update sheet).

import SwiftUI

struct FeatureCard: View {
    let icon: String
    let title: String
    private let bodyText: String

    init(icon: String, title: String, body: String) {
        self.icon = icon
        self.title = title
        self.bodyText = body
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(bodyText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }
}
