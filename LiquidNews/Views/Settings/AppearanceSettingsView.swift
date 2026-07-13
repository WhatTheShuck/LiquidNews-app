// AppearanceSettingsView.swift
// Colour scheme, app theme, accent colour, and app icon.

import SwiftUI
import PhotosUI

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
            .glassSheet()
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
    /// The premium theme awaiting confirmation; presenting the trial-start sheet.
    @State private var pendingTrialTheme: AppThemePreset?
    /// Trial-start confirmation for unlocking the custom accent picker.
    @State private var showAccentTrialSheet = false
    @State private var photoPickerItem: PhotosPickerItem?
    /// Deferred background edit awaiting trial-start confirmation.
    @State private var pendingBackgroundEdit: PendingBackgroundEdit?

    private struct PendingBackgroundEdit: Identifiable {
        let id = UUID()
        let apply: () -> Void
    }

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
                .sheet(item: $pendingTrialTheme) { preset in
                    NavigationStack {
                        TrialStartSheet {
                            paymentsStore.startTrialIfNeeded()
                            settings.selectedAppTheme = preset
                        }
                    }
                    .presentationDetents([.medium])
                    .presentationCornerRadius(.glassCornerRadius)
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
                        if paymentsStore.themesAccessible {
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
                        } else {
                            // Locked: the picker is premium, mirroring locked
                            // theme rows. Sibling of the Reset button (not its
                            // parent) so both stay independently tappable.
                            Button {
                                switch paymentsStore.trialState {
                                case .notStarted:
                                    showAccentTrialSheet = true
                                case .hardExpired:
                                    showPaywall = true
                                case .active, .grace:
                                    break // unreachable: themesAccessible is true here
                                }
                            } label: {
                                HStack {
                                    Text("Custom Accent")
                                        .font(.system(size: rowSize))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: labelSize))
                                        .foregroundStyle(Color.secondary)
                                }
                                .frame(minHeight: 32)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        // Clearing a premium customisation is never premium —
                        // Reset stays available even while locked.
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
                .sheet(isPresented: $showAccentTrialSheet) {
                    NavigationStack {
                        TrialStartSheet {
                            // No colour to apply — starting the trial unlocks
                            // the picker in place.
                            paymentsStore.startTrialIfNeeded()
                        }
                    }
                    .presentationDetents([.medium])
                    .presentationCornerRadius(.glassCornerRadius)
                }

                // Custom background
                VStack(alignment: .leading, spacing: 0) {
                    Text("Background")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Background", selection: backgroundKindBinding) {
                            Text("Theme").tag(CustomBackgroundKind.none)
                            Text("Colour").tag(CustomBackgroundKind.solid)
                            Text("Gradient").tag(CustomBackgroundKind.gradient)
                            Text("Photo").tag(CustomBackgroundKind.image)
                        }
                        .pickerStyle(.segmented)
                        .tint(AppTheme.accent)

                        backgroundEditor

                        if settings.customBackgroundKind != .none {
                            Button {
                                resetCustomBackground()
                            } label: {
                                Text("Reset to Theme Background")
                                    .font(.system(size: labelSize))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .glassCard()
                }
                .sheet(item: $pendingBackgroundEdit) { edit in
                    NavigationStack {
                        TrialStartSheet {
                            paymentsStore.startTrialIfNeeded()
                            edit.apply()
                        }
                    }
                    .presentationDetents([.medium])
                    .presentationCornerRadius(.glassCornerRadius)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(ThemeBackground().ignoresSafeArea())
        .navigationTitle("App Theme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                defer { photoPickerItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                do {
                    try CustomBackgroundStore.save(image, maxPixelEdge: CustomBackgroundStore.maxPixelEdge)
                    settings.customBackgroundImageRevision = UUID().uuidString
                } catch {
                    // Failed write leaves the previous image and revision untouched.
                }
            }
        }
        .task {
            if paymentsStore.trialState == .hardExpired && !paymentsStore.isThemesUnlocked
                && (settings.selectedAppTheme.isPremium || settings.customBackgroundKind != .none
                    || settings.customAccentHex != nil) {
                showExpiredNudge = true
            }
        }
        .alert("Trial Ended", isPresented: $showExpiredNudge) {
            Button("Unlock Themes") { showPaywall = true }
            Button("Use Default", role: .destructive) {
                settings.selectedAppTheme = .standard
                settings.customAccentHex = nil
                resetCustomBackground()
            }
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
                    // Confirm the trial before silently opting the user in.
                    pendingTrialTheme = preset
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

    // MARK: - Custom background section

    /// Gates kind changes behind the Themes unlock, mirroring the premium
    /// theme-row flow. Edits *within* an active kind (colour tweaks, sliders)
    /// are not gated: a non-none kind already required access, and expiry is
    /// handled by the Trial Ended nudge.
    private var backgroundKindBinding: Binding<CustomBackgroundKind> {
        Binding(
            get: { settings.customBackgroundKind },
            set: { newKind in
                guard newKind != settings.customBackgroundKind else { return }
                if newKind == .none {
                    resetCustomBackground()
                    return
                }
                if paymentsStore.isThemesUnlocked {
                    applyBackgroundKind(newKind)
                    return
                }
                switch paymentsStore.trialState {
                case .notStarted:
                    pendingBackgroundEdit = PendingBackgroundEdit { applyBackgroundKind(newKind) }
                case .active, .grace:
                    applyBackgroundKind(newKind)
                case .hardExpired:
                    showPaywall = true
                }
            }
        )
    }

    private func applyBackgroundKind(_ kind: CustomBackgroundKind) {
        let swatchHex = settings.selectedAppTheme.swatchColor.toHexString()
        switch kind {
        case .solid:
            settings.customBackgroundHexes = [swatchHex]
        case .gradient:
            settings.customBackgroundHexes = [swatchHex, "000000"]
        case .image, .none:
            break
        }
        settings.customBackgroundKind = kind
    }

    private func resetCustomBackground() {
        settings.customBackgroundKind = .none
        settings.customBackgroundHexes = []
        settings.customBackgroundDim = 0.35
        settings.customBackgroundBlur = 0
        settings.customBackgroundImageRevision = nil
        CustomBackgroundStore.delete()
    }

    @ViewBuilder
    private var backgroundEditor: some View {
        switch settings.customBackgroundKind {
        case .none:
            EmptyView()
        case .solid:
            ColorPicker("Colour", selection: solidColorBinding, supportsOpacity: false)
                .font(.system(size: rowSize))
        case .gradient:
            ForEach(0..<settings.customBackgroundHexes.count, id: \.self) { index in
                ColorPicker("Colour \(index + 1)", selection: gradientColorBinding(index), supportsOpacity: false)
                    .font(.system(size: rowSize))
            }
            Button {
                if settings.customBackgroundHexes.count < 3 {
                    settings.customBackgroundHexes.append("000000")
                } else {
                    settings.customBackgroundHexes.removeLast()
                }
            } label: {
                Text(settings.customBackgroundHexes.count < 3 ? "Add Third Colour" : "Remove Third Colour")
                    .font(.system(size: labelSize))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
        case .image:
            HStack(spacing: 12) {
                if let revision = settings.customBackgroundImageRevision,
                   let image = CustomBackgroundStore.cachedImage(revision: revision) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.glassBorder, lineWidth: 1))
                }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Text(settings.customBackgroundImageRevision == nil ? "Choose Photo" : "Change Photo")
                        .font(.system(size: rowSize))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            HStack {
                Text("Dim").font(.system(size: rowSize))
                Slider(value: $settings.customBackgroundDim, in: 0...0.8)
                    .tint(AppTheme.accent)
            }
            HStack {
                Text("Blur").font(.system(size: rowSize))
                Slider(value: $settings.customBackgroundBlur, in: 0...20)
                    .tint(AppTheme.accent)
            }
        }
    }

    private var solidColorBinding: Binding<Color> {
        Binding(
            get: {
                settings.customBackgroundHexes.first.flatMap(Color.init(hexString:))
                    ?? settings.selectedAppTheme.swatchColor
            },
            set: { settings.customBackgroundHexes = [$0.toHexString()] }
        )
    }

    private func gradientColorBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard settings.customBackgroundHexes.indices.contains(index),
                      let color = Color(hexString: settings.customBackgroundHexes[index]) else { return .black }
                return color
            },
            set: { color in
                var hexes = settings.customBackgroundHexes
                while hexes.count <= index { hexes.append("000000") }
                hexes[index] = color.toHexString()
                settings.customBackgroundHexes = hexes
            }
        )
    }
}
