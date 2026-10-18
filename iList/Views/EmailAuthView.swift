import SwiftUI

// MARK: - Email + password (entrar, criar conta, recuperar)
struct EmailAuthView: View {
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.dismiss) var dismiss

    enum Mode { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var awaitingConfirmation = false

    private var emailValid: Bool {
        let parts = email.trimmingCharacters(in: .whitespaces).split(separator: "@")
        return parts.count == 2 && parts[1].contains(".")
    }
    private var canSubmit: Bool { emailValid && password.count >= 8 && !session.isWorking }

    var body: some View {
        NavigationStack {
            Form {
                if awaitingConfirmation {
                    Section {
                        Label("login.email.checkInbox", systemImage: "envelope.badge")
                        Text(email).foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Picker("", selection: $mode) {
                            Text("login.email.signIn").tag(Mode.signIn)
                            Text("login.email.signUp").tag(Mode.signUp)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        TextField("login.email.address", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("login.email.password", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                    } footer: {
                        if mode == .signUp { Text("login.email.passwordHint") }
                    }

                    Section {
                        Button(action: submit) {
                            HStack {
                                Spacer()
                                if session.isWorking { ProgressView() }
                                else { Text(mode == .signIn ? "login.email.signIn" : "login.email.signUp").bold() }
                                Spacer()
                            }
                        }
                        .disabled(!canSubmit)
                    }

                    if mode == .signIn {
                        Section {
                            Button("login.email.forgot") {
                                Task { await session.resetPassword(email: email.trimmingCharacters(in: .whitespaces)) }
                            }
                            .disabled(!emailValid || session.isWorking)
                        }
                    }
                }
            }
            .navigationTitle("login.email.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("catalog.close") { dismiss() }
                }
            }
            .onChange(of: session.userId) { _, id in
                if id != nil { dismiss() }
            }
        }
    }

    private func submit() {
        let address = email.trimmingCharacters(in: .whitespaces)
        Task {
            if mode == .signIn {
                await session.signIn(email: address, password: password)
            } else if await session.signUp(email: address, password: password) {
                awaitingConfirmation = true
            }
        }
    }
}

// MARK: - Nova password (depois do link de recuperação)
struct NewPasswordView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("login.email.newPassword", text: $password)
                        .textContentType(.newPassword)
                } footer: {
                    Text("login.email.passwordHint")
                }
                Section {
                    Button("action.save") {
                        Task { await session.updatePassword(password) }
                    }
                    .disabled(password.count < 8 || session.isWorking)
                }
            }
            .navigationTitle("login.email.newPassword")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}
