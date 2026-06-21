// SidebarView.swift
// The sidebar (leading column) of the iPad/Mac split view. Lists Search, every
// enabled tab in the user's configured order (Feed always first, no overflow
// limit), then Settings and Account. Selection drives model.destination.

import SwiftUI

struct SidebarView: View {
    let model: iPadNavModel
    @State private var settings = UserSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    /// Feed first, then enabled optional tabs in the user's configured order.
    private var enabledTabs: [AppTab] {
        [.feed] + settings.tabOrder.filter { settings.enabledOptionalTabs.contains($0) }
    }

    /// Optional binding required by iOS's single-selection List initializer.
    /// A nil set (deselection) is ignored so the sidebar always keeps a
    /// destination selected.
    private var selection: Binding<SidebarDestination?> {
        Binding(
            get: { model.destination },
            set: { if let new = $0 { model.destination = new } }
        )
    }

    var body: some View {
        List(selection: selection) {
            Section {
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarDestination.search)
            }

            Section {
                ForEach(enabledTabs) { tab in
                    Label(tab.label, systemImage: tab.systemImage)
                        .tag(SidebarDestination.tab(tab))
                }
            }

            Section {
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarDestination.settings)
                Label("Account", systemImage: "person.crop.circle")
                    .tag(SidebarDestination.account)
            }
        }
        .navigationTitle("LiquidNews")
        .scrollContentBackground(.hidden)
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
    }
}
