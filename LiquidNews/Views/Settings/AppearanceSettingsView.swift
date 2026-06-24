// AppearanceSettingsView.swift
// Colour scheme, app theme, accent colour, and app icon.

import SwiftUI

struct AppearanceSettingsView: View {

    @State private var settings = UserSettings.shared
    @State private var paymentsStore = StoreService.shared
    @State private var showThemePaywall = false
    @State private var showThemePicker = false
    @AppStorage(AppIconStorage.familyKey) private var iconFamilyRaw: String = AppIconFamily.default.rawValue

    @ScaledMetric(relativeTo: .body)    private var rowFontSize:      CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var subtitleFontSize: CGFloat = 12

    var body: some View {
        SettingsDetailScaffold(title: "Appearance") {
            VStack(alignment: .leading, spacing: 0) {
                // Color Scheme row
                HStack {
                    Label("Color Scheme", systemImage: "circle.lefthalf.filled")
                        .foregroundStyle(.primary)
                        .font(.system(size: rowFontSize))
                    Spacer()
                    Picker("Color Scheme", selection: $settings.appColorScheme) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            Text(scheme.label).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                    .tint(AppTheme.accent)
                }
                .padding(16)

                Divider().overlay(AppTheme.glassBorder)

                // App Theme row
                Button {
                    showThemePicker = true
                } label: {
                    HStack {
                        Label("App Theme", systemImage: "paintpalette")
                            .foregroundStyle(.primary)
                            .font(.system(size: rowFontSize))
                        Spacer()
                        Text(settings.selectedAppTheme.label)
                            .font(.system(size: subtitleFontSize))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: subtitleFontSize, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                Divider().overlay(AppTheme.glassBorder)

                HStack(spacing: 12) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30)
                    Text("App Icon")
                        .font(.system(size: rowFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

                HStack(spacing: 24) {
                    iconChoice(label: "Droplet", family: .default, imageName: "AppIconPreview")
                    iconChoice(label: "Letter", family: .letter, imageName: "AppIconAltPreview")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .glassCard()
        }
        .sheet(isPresented: $showThemePaywall) {
            NavigationStack {
                PremiumPaywallView(focused: StoreService.ProductID.themes)
            }
            .presentationCornerRadius(.glassCornerRadius)
        }
        .sheet(isPresented: $showThemePicker) {
            NavigationStack {
                AppThemePickerView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(.glassCornerRadius)
        }
    }

    @ViewBuilder
    private func iconChoice(label: String, family: AppIconFamily, imageName: String) -> some View {
        let isSelected = (AppIconFamily(rawValue: iconFamilyRaw) ?? .default) == family
        Button {
            iconFamilyRaw = family.rawValue
        } label: {
            VStack(spacing: 10) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? AppTheme.accent : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )

                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? AppTheme.accent : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
}

// MARK: - App Theme Picker

private struct AppThemePickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings = UserSettings.shared
    @State private var paymentsStore = StoreService.shared
    @State private var showPaywall = false
    @State private var showExpiredNudge = false

    @ScaledMetric(relativeTo: .body)     private var rowSize:   CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var labelSize: CGFloat = 12

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                // Theme presets
                VStack(spacing: 0) {
                    ForEach(Array(AppThemePreset.allCases.enumerated()), id: \.element.id) { index, preset in
                        if index > 0 { Divider().overlay(AppTheme.glassBorder) }
                        themePresetRow(preset)
                    }
                }
                .glassCard()
                .sheet(isPresented: $showPaywall) {
                    NavigationStack {
                        PremiumPaywallView(focused: StoreService.ProductID.themes)
                    }
                }

                // Custom accent color picker
                VStack(alignment: .leading, spacing: 0) {
                    Text("Accent Color")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    HStack {
                        Text("Custom Accent")
                            .font(.system(size: rowSize))
                            .foregroundStyle(.primary)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: {
                                if let hex = settings.customAccentHex,
                                   let color = Color(hexString: hex) { return color }
                                return settings.selectedAppTheme.accent
                            },
                            set: { color in
                                settings.customAccentHex = color.toHexString()
                            }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 44, height: 32)

                        if settings.customAccentHex != nil {
                            Button {
                                settings.customAccentHex = nil
                            } label: {
                                Text("Reset")
                                    .font(.system(size: labelSize))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .glassCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("App Theme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            if paymentsStore.trialState == .hardExpired && !paymentsStore.isThemesUnlocked && settings.selectedAppTheme.isPremium {
                showExpiredNudge = true
            }
        }
        .alert("Trial Ended", isPresented: $showExpiredNudge) {
            Button("Unlock Themes") { showPaywall = true }
            Button("Use Default", role: .destructive) { settings.selectedAppTheme = .standard }
        } message: {
            Text("Your 7-day free trial has ended. Unlock Themes to keep your current theme.")
        }
    }

    @ViewBuilder
    private func themePresetRow(_ preset: AppThemePreset) -> some View {
        let locked = preset.isPremium && !paymentsStore.themesAccessible
        Button {
            if preset.isPremium && !paymentsStore.isThemesUnlocked {
                switch paymentsStore.trialState {
                case .notStarted:
                    paymentsStore.startTrialIfNeeded()
                    settings.selectedAppTheme = preset
                case .active, .grace:
                    settings.selectedAppTheme = preset
                case .hardExpired:
                    showPaywall = true
                }
            } else {
                settings.selectedAppTheme = preset
            }
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(preset.swatchColor)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().strokeBorder(AppTheme.glassBorder, lineWidth: 1))
                Text(preset.label)
                    .font(.system(size: rowSize, design: .rounded))
                    .foregroundStyle(locked ? Color.secondary : Color.primary)
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: labelSize))
                        .foregroundStyle(Color.secondary)
                } else if settings.selectedAppTheme == preset {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
