// CommentBadge.swift
// Small pill badge used inside comment headers to mark mod / OP / current-user / etc.

import SwiftUI

struct CommentBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.5))
    }
}
