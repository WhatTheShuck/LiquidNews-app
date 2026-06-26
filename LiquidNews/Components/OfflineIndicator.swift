// OfflineIndicator.swift
// A compact "Offline" pill shown in the feed's navigation bar while offline — a quiet,
// contained status cue rather than a full-width banner that tints the whole top.

import SwiftUI

struct OfflineIndicator: View {
    @State private var monitor = NetworkMonitor.shared

    var body: some View {
        if !monitor.isOnline {
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 11, weight: .semibold))
                Text("Offline")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            //            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
           // .background(.quaternary, in: Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
            .accessibilityLabel("You're offline")
        }
    }
}
 
