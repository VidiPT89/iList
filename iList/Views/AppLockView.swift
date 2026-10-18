import SwiftUI

// MARK: - Bloqueio da app (Face ID → PIN)
struct AppLockView: View {
    @EnvironmentObject var session: SessionViewModel

    enum Mode { case faceID, pin }

    @State private var mode: Mode = .pin
    @State private var pinInput = ""
    @State private var shake = false
    @State private var errorMsg: String?
    @State private var showResetConfirm = false

    private var color: Color { session.myColor }
    private var pinLen: Int { KeychainService.shared.pinLength }
    private var biometricEnabled: Bool {
        KeychainService.shared.isBiometricEnabled && BiometricService.shared.isAvailable
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    avatarView(name: session.displayName, color: color, size: 90)
                    Text(session.displayName)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 70)

                Spacer()

                if mode == .faceID && biometricEnabled {
                    faceIDContent
                } else {
                    pinContent
                }

                Spacer()
            }
        }
        .onAppear {
            mode = biometricEnabled ? .faceID : .pin
            if biometricEnabled { Task { await tryBiometric() } }
        }
        .alert("pin.reset.confirm.title", isPresented: $showResetConfirm) {
            Button("action.cancel", role: .cancel) {}
            Button("pin.reset.confirm.action", role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text("pin.reset.confirm.message")
        }
    }

    var faceIDContent: some View {
        VStack(spacing: 28) {
            Image(systemName: BiometricService.shared.systemImageName)
                .font(.system(size: 72))
                .foregroundStyle(color)

            Text(String(format: L("pin.waiting"), BiometricService.shared.label))
                .foregroundStyle(.white.opacity(0.5))
                .font(.subheadline)

            VStack(spacing: 14) {
                Button { Task { await tryBiometric() } } label: {
                    Text("pin.retry")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(color)
                }
                Button { withAnimation { mode = .pin; pinInput = ""; errorMsg = nil } } label: {
                    Text("pin.useCode")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.bottom, 20)
    }

    var pinContent: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                PINDotsView(count: pinLen, filled: pinInput.count)
                    .modifier(ShakeEffect(trigger: shake))
                if let err = errorMsg {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }
            }

            PINPadView(accentColor: color) { handleKey($0) }

            if biometricEnabled {
                Button {
                    withAnimation { mode = .faceID; errorMsg = nil }
                    Task { await tryBiometric() }
                } label: {
                    Label(String(format: L("pin.useBiometric"), BiometricService.shared.label),
                          systemImage: BiometricService.shared.systemImageName)
                        .font(.footnote)
                        .foregroundStyle(color)
                }
            }

            Button { showResetConfirm = true } label: {
                Text("pin.forgot")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private func tryBiometric() async {
        let ok = await BiometricService.shared.authenticate(reason: L("pin.biometric.reason"))
        if ok { session.unlock() } else { withAnimation { mode = .pin } }
    }

    private func handleKey(_ key: PINKey) {
        switch key {
        case .digit(let d):
            guard pinInput.count < pinLen else { return }
            pinInput.append(d)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if pinInput.count == pinLen { verifyPIN() }
        case .delete:
            if !pinInput.isEmpty { pinInput.removeLast() }
            errorMsg = nil
        }
    }

    private func verifyPIN() {
        if pinInput == KeychainService.shared.getPIN() {
            errorMsg = nil
            session.unlock()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
            errorMsg = L("pin.error.wrong")
            pinInput = ""
        }
    }
}
