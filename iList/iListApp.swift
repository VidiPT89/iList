import SwiftUI

@main
struct iListApp: App {
    @StateObject private var session = SessionViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorSchemePreference") private var colorSchemePreference: Int = 0
    @AppStorage("languagePreference") private var languagePreference: String = "pt-PT"
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash || session.phase == .loading {
                    SplashView()
                        .transition(.opacity)
                } else {
                    content
                        .transition(.opacity)
                    if session.isLocked && session.phase != .signedOut {
                        AppLockView()
                            .transition(.opacity)
                    }
                }
            }
            .environmentObject(session)
            .animation(.easeOut(duration: 0.35), value: showSplash)
            .animation(.easeOut(duration: 0.3), value: session.phase)
            .animation(.easeOut(duration: 0.3), value: session.isLocked)
            .environment(\.locale, Locale(identifier: languagePreference))
            .onOpenURL { url in
                Task { await session.handle(url: url) }
            }
            // Links universais (https://ividi.dev/ilist/join?code=…)
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { Task { await session.handle(url: url) } }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background: session.lockIfNeeded()
                case .active: Task { await session.refresh() }
                default: break
                }
            }
            .alert(Text(verbatim: session.errorMessage ?? ""), isPresented: Binding(
                get: { session.errorMessage != nil },
                set: { if !$0 { session.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
            .alert(Text(verbatim: session.infoMessage ?? ""), isPresented: Binding(
                get: { session.infoMessage != nil && session.errorMessage == nil },
                set: { if !$0 { session.infoMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $session.needsNewPassword) {
                NewPasswordView().environmentObject(session)
            }
            .onAppear {
                applyColorScheme(colorSchemePreference)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    showSplash = false
                }
            }
            .onChange(of: colorSchemePreference) { _, v in applyColorScheme(v) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .loading, .signedOut:
            LoginView()
        case .needsName:
            OnboardingNameView()
        case .needsHousehold:
            HouseholdSetupView()
        case .ready:
            if let household = session.currentHousehold {
                HomeView(household: household)
            }
        }
    }

    private func applyColorScheme(_ preference: Int) {
        let style: UIUserInterfaceStyle
        switch preference {
        case 1: style = .light
        case 2: style = .dark
        default: style = .unspecified
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
    }
}
