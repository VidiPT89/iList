import AuthenticationServices
import SwiftUI

// MARK: - Login (Apple, Google, email)
struct LoginView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var appleNonce = ""
    @State private var showEmail = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.12, blue: 0.16),
                         Color(red: 0.06, green: 0.08, blue: 0.10)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                    Text("iList")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("login.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { request in
                        appleNonce = AppleNonce.random()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleNonce.sha256(appleNonce)
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    providerButton("login.google", icon: "g.circle.fill") {
                        Task { await session.signInWithOAuth(.google) }
                    }
                    providerButton("login.email", icon: "envelope.fill") {
                        showEmail = true
                    }
                }
                .disabled(session.isWorking)

                VStack(spacing: 4) {
                    Text("login.legal")
                    Link(destination: AppConfig.privacyPolicyURL) {
                        Text("settings.privacy").underline()
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)

            if session.isWorking {
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
        .sheet(isPresented: $showEmail) {
            EmailAuthView().environmentObject(session)
        }
    }

    private func providerButton(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15)))
            )
        }
        .buttonStyle(.plain)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                session.errorMessage = L("error.generic")
                return
            }
            Task {
                await session.signInWithApple(idToken: idToken, nonce: appleNonce, fullName: credential.fullName)
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                session.errorMessage = L("error.generic")
            }
        }
    }
}
