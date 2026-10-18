import SwiftUI

// MARK: - Ativar bloqueio da app (PIN + biometria opcional)
struct PINSetupView: View {
    let accentColor: Color
    @Environment(\.dismiss) var dismiss

    enum Step { case pinLength, pinEnter, pinConfirm, biometric }

    @State private var step: Step = .pinLength
    @State private var pinLen = 6
    @State private var pinFirst = ""
    @State private var pinInput = ""
    @State private var shake = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(11)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .padding(.leading, 20).padding(.top, 16)
                    Spacer()
                }

                switch step {
                case .pinLength:  pinLengthStep
                case .pinEnter:   pinEntryStep(isConfirm: false)
                case .pinConfirm: pinEntryStep(isConfirm: true)
                case .biometric:  biometricStep
                }
            }
        }
    }

    var pinLengthStep: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(accentColor)
                Text("pin.setup.title")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("pin.setup.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 20) {
                ForEach([4, 6], id: \.self) { len in
                    Button {
                        pinLen = len
                        withAnimation { step = .pinEnter }
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(len)")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                            Text("pin.length.digits").font(.caption)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(accentColor.opacity(0.18))
                                .overlay(RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(accentColor, lineWidth: 2))
                        )
                    }
                }
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }

    func pinEntryStep(isConfirm: Bool) -> some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 10) {
                Text(isConfirm ? "pin.confirm.title" : "pin.create.title")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Group {
                    if isConfirm {
                        Text("pin.confirm.subtitle")
                    } else {
                        Text(String(format: L("pin.create.subtitle"), pinLen))
                    }
                }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
            }

            PINDotsView(count: pinLen, filled: pinInput.count)
                .modifier(ShakeEffect(trigger: shake))

            PINPadView(accentColor: accentColor) { handleSetupKey($0, isConfirm: isConfirm) }

            Spacer()
        }
        .onAppear { pinInput = "" }
    }

    func handleSetupKey(_ key: PINKey, isConfirm: Bool) {
        switch key {
        case .digit(let d):
            guard pinInput.count < pinLen else { return }
            pinInput.append(d)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard pinInput.count == pinLen else { return }

            if isConfirm {
                if pinInput == pinFirst {
                    KeychainService.shared.savePIN(pinFirst)
                    KeychainService.shared.setPINLength(pinLen)
                    withAnimation { step = .biometric }
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) { shake = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
                    pinInput = ""
                }
            } else {
                pinFirst = pinInput
                withAnimation { step = .pinConfirm }
            }
        case .delete:
            if !pinInput.isEmpty { pinInput.removeLast() }
        }
    }

    var biometricStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: BiometricService.shared.isAvailable
                  ? BiometricService.shared.systemImageName
                  : "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(accentColor)

            VStack(spacing: 10) {
                Group {
                    if BiometricService.shared.isAvailable {
                        Text(String(format: L("pin.biometric.enableTitle"), BiometricService.shared.label))
                    } else {
                        Text("pin.biometric.createdTitle")
                    }
                }
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Group {
                    if BiometricService.shared.isAvailable {
                        Text(String(format: L("pin.biometric.enableSubtitle"), BiometricService.shared.label))
                    } else {
                        Text("pin.biometric.createdSubtitle")
                    }
                }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 14) {
                if BiometricService.shared.isAvailable {
                    Button {
                        KeychainService.shared.setBiometricEnabled(true)
                        dismiss()
                    } label: {
                        Text(String(format: L("pin.biometric.enableButton"), BiometricService.shared.label))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                Button { dismiss() } label: {
                    Text(BiometricService.shared.isAvailable ? "pin.biometric.notNow" : "pin.biometric.enter")
                        .font(.subheadline)
                        .foregroundStyle(BiometricService.shared.isAvailable
                                         ? .white.opacity(0.35) : accentColor)
                }
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }
}
