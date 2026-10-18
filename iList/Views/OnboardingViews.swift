import SwiftUI

// MARK: - Nome (o que os outros membros veem)
struct OnboardingNameView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingScaffold(icon: "person.crop.circle", title: "onboarding.name.title",
                           subtitle: "onboarding.name.subtitle") {
            TextField("onboarding.name.placeholder", text: $name)
                .textContentType(.givenName)
                .focused($focused)
                .onboardingField()
                .onSubmit(save)

            primaryButton("action.continue", disabled: name.trimmingCharacters(in: .whitespaces).isEmpty, action: save)

            Button("settings.signOut") { Task { await session.signOut() } }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.4))
        }
        .onAppear { focused = true }
    }

    private func save() { Task { await session.saveName(name) } }
}

// MARK: - Criar ou entrar numa lista
struct HouseholdSetupView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var listName = ""
    @State private var code = ""

    var body: some View {
        OnboardingScaffold(icon: "person.2.fill", title: "onboarding.list.title",
                           subtitle: "onboarding.list.subtitle") {
            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.list.create").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                TextField("onboarding.list.namePlaceholder", text: $listName)
                    .onboardingField()
                primaryButton("onboarding.list.createButton",
                              disabled: listName.trimmingCharacters(in: .whitespaces).isEmpty) {
                    Task { await session.createHousehold(name: listName) }
                }
            }

            HStack {
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                Text("onboarding.or").font(.caption).foregroundStyle(.white.opacity(0.4))
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.list.join").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                TextField("onboarding.list.codePlaceholder", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .onboardingField()
                primaryButton("onboarding.list.joinButton", disabled: InviteLink.normalize(code) == nil) {
                    Task { await session.join(code: code) }
                }
            }

            Button("settings.signOut") { Task { await session.signOut() } }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - Estrutura comum
struct OnboardingScaffold<Content: View>: View {
    @EnvironmentObject var session: SessionViewModel
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 54))
                            .foregroundStyle(session.myColor)
                        Text(title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)

                    content
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

            if session.isWorking {
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
    }
}

private extension View {
    func onboardingField() -> some View {
        self
            .padding(.horizontal, 16)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
    }
}

@MainActor
private func primaryButton(_ title: LocalizedStringKey, disabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.accentColor.opacity(disabled ? 0.35 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .disabled(disabled)
}
