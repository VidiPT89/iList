import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) var dismiss
    @AppStorage("colorSchemePreference") private var colorSchemePreference: Int = 0
    @AppStorage("languagePreference") private var languagePreference: String = "pt-PT"

    @State private var showRename = false
    @State private var newName = ""
    @State private var showPINSetup = false
    @State private var lockEnabled = KeychainService.shared.isLockEnabled
    @State private var biometricEnabled = KeychainService.shared.isBiometricEnabled
    @State private var showDeleteConfirm = false

    private var accent: Color { session.myColor }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileCard
                    ListSettingsSection()
                    securityCard
                    appearanceCard
                    languageCard
                    accountCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .alert("settings.rename.title", isPresented: $showRename) {
                TextField("onboarding.name.placeholder", text: $newName)
                Button("action.cancel", role: .cancel) {}
                Button("action.save") { Task { await session.saveName(newName) } }
            }
            .alert("settings.delete.title", isPresented: $showDeleteConfirm) {
                Button("action.cancel", role: .cancel) {}
                Button("settings.delete.action", role: .destructive) {
                    Task { await session.deleteAccount() }
                }
            } message: {
                Text("settings.delete.message")
            }
            .sheet(isPresented: $showPINSetup, onDismiss: {
                lockEnabled = KeychainService.shared.isLockEnabled
                biometricEnabled = KeychainService.shared.isBiometricEnabled
            }) {
                PINSetupView(accentColor: accent)
            }
        }
        .task { await session.reloadMembers() }
        // Apply locale here — propagates to all child views including the NavigationStack
        .environment(\.locale, Locale(identifier: languagePreference))
    }

    // MARK: Profile card
    var profileCard: some View {
        Button {
            newName = session.displayName
            showRename = true
        } label: {
            HStack(spacing: 16) {
                avatarView(name: session.displayName, color: accent, size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("settings.rename.hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "pencil").foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: Security card (bloqueio opcional)
    var securityCard: some View {
        settingsCard(title: "settings.security") {
            VStack(spacing: 14) {
                Toggle(isOn: Binding(
                    get: { lockEnabled },
                    set: { on in
                        if on { showPINSetup = true }
                        else {
                            KeychainService.shared.deletePIN()
                            lockEnabled = false
                            biometricEnabled = false
                        }
                    }
                )) {
                    Label("settings.lock", systemImage: "lock.fill")
                }
                .tint(accent)

                if lockEnabled && BiometricService.shared.isAvailable {
                    Divider()
                    Toggle(isOn: Binding(
                        get: { biometricEnabled },
                        set: { KeychainService.shared.setBiometricEnabled($0); biometricEnabled = $0 }
                    )) {
                        Label(BiometricService.shared.label, systemImage: BiometricService.shared.systemImageName)
                    }
                    .tint(accent)
                }
            }
        }
    }

    // MARK: Appearance card
    var appearanceCard: some View {
        settingsCard(title: "settings.appearance") {
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStringKey("settings.theme"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 0) {
                    themeButton(key: "settings.theme.system", icon: "circle.lefthalf.filled", value: 0)
                    themeButton(key: "settings.theme.light",  icon: "sun.max",               value: 1)
                    themeButton(key: "settings.theme.dark",   icon: "moon.stars",            value: 2)
                }
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: Language card
    var languageCard: some View {
        settingsCard(title: "settings.language") {
            HStack(spacing: 0) {
                langButton(label: "🇵🇹  Português", code: "pt-PT")
                langButton(label: "🇬🇧  English",   code: "en")
            }
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Account card
    var accountCard: some View {
        settingsCard(title: "settings.account") {
            VStack(alignment: .leading, spacing: 14) {
                Link(destination: AppConfig.privacyPolicyURL) {
                    Label("settings.privacy", systemImage: "hand.raised.fill")
                }
                Divider()
                Button {
                    Task { await session.signOut() }
                } label: {
                    Label("settings.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                }
                Divider()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("settings.delete.title", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .tint(accent)
        }
    }

    // MARK: Theme button
    func themeButton(key: LocalizedStringKey, icon: String, value: Int) -> some View {
        let selected = colorSchemePreference == value
        return Button {
            colorSchemePreference = value
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(key)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? accent : Color.clear)
            .foregroundStyle(selected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.15), value: selected)
        }
        .buttonStyle(.plain)
    }

    // MARK: Language button
    func langButton(label: String, code: String) -> some View {
        let selected = languagePreference == code
        return Button {
            languagePreference = code
            WidgetSnapshot.updateLanguage(code)
            WidgetCenter.shared.reloadTimelines(ofKind: "iListWidget")
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? accent : Color.clear)
                .foregroundStyle(selected ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeInOut(duration: 0.15), value: selected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card wrapper (partilhado com ListSettingsSection)
func settingsCard(title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)

        content()
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
