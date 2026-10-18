import AuthenticationServices
import Foundation
import Supabase
import SwiftUI
import WidgetKit

/// Estado da conta: sessão Supabase, nome, listas a que pertence e bloqueio local.
@MainActor
final class SessionViewModel: ObservableObject {
    enum Phase: Equatable { case loading, signedOut, needsName, needsHousehold, ready }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var userId: UUID?
    @Published private(set) var displayName = ""
    @Published private(set) var households: [Household] = []
    @Published private(set) var currentHousehold: Household?
    @Published private(set) var members: [HouseholdMember] = []
    @Published var isLocked = KeychainService.shared.isLockEnabled
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    /// O utilizador abriu o link de recuperação: tem de escolher uma password nova.
    @Published var needsNewPassword = false

    /// Convite aberto por link antes de haver sessão — usado logo a seguir ao login.
    private var pendingInviteCode: String?
    /// Nome dado pela Apple no primeiro login (só chega nesse momento, nunca mais).
    private var pendingAppleName: String?
    private let currentHouseholdKey = "currentHouseholdId"
    private var supabase: SupabaseClient { SupabaseService.shared.client }

    var myColor: Color { MemberColor.color(for: userId?.uuidString ?? "") }
    var isOwnerOfCurrent: Bool { members.first { $0.userId == userId }?.isOwner ?? false }

    init() {
        Task { await observeAuth() }
    }

    // MARK: - Sessão
    private func observeAuth() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn:
                if let session {
                    if session.user.id != userId { await didSignIn(session.user) }
                } else {
                    resetState()
                }
            case .passwordRecovery:
                needsNewPassword = true
            case .signedOut, .userDeleted:
                resetState()
            default:
                break
            }
        }
    }

    private func didSignIn(_ user: User) async {
        userId = user.id
        await loadProfile(user)
        if displayName.isEmpty, let name = pendingAppleName {
            await saveName(name)
        }
        pendingAppleName = nil
        await loadHouseholds()
        if let code = pendingInviteCode {
            pendingInviteCode = nil
            await join(code: code)
        }
        updatePhase()
    }

    private func resetState() {
        userId = nil
        displayName = ""
        households = []
        currentHousehold = nil
        members = []
        isLocked = false
        phase = .signedOut
        WidgetSnapshot.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: "iListWidget")
    }

    private func updatePhase() {
        guard userId != nil else { phase = .signedOut; return }
        if displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            phase = .needsName
        } else if currentHousehold == nil {
            phase = .needsHousehold
        } else {
            phase = .ready
        }
    }

    /// Recarrega listas e membros (ex.: ao voltar à app, ou depois de alguém nos adicionar).
    func refresh() async {
        guard userId != nil else { return }
        await loadHouseholds()
        updatePhase()
    }

    // MARK: - Login
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async {
        if let fullName {
            let name = PersonNameComponentsFormatter().string(from: fullName)
            pendingAppleName = name.isEmpty ? nil : name
        }
        await perform {
            try await self.supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
        }
    }

    func signInWithOAuth(_ provider: Provider) async {
        await perform {
            try await self.supabase.auth.signInWithOAuth(
                provider: provider,
                redirectTo: AppConfig.authCallbackURL
            )
        }
    }

    func signIn(email: String, password: String) async {
        await perform {
            try await self.supabase.auth.signIn(email: email, password: password)
        }
    }

    /// Devolve `true` se a conta precisa de confirmação por email antes de entrar.
    func signUp(email: String, password: String) async -> Bool {
        var needsConfirmation = false
        await perform {
            let response = try await self.supabase.auth.signUp(email: email, password: password)
            if case .user = response { needsConfirmation = true }
        }
        return needsConfirmation
    }

    func resetPassword(email: String) async {
        await perform {
            try await self.supabase.auth.resetPasswordForEmail(email)
            self.infoMessage = L("login.email.resetSent")
        }
    }

    func updatePassword(_ password: String) async {
        await perform {
            try await self.supabase.auth.update(user: UserAttributes(password: password))
            self.needsNewPassword = false
            self.infoMessage = L("login.email.passwordUpdated")
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut(scope: .local)
        KeychainService.shared.deletePIN()
        resetState()
    }

    func deleteAccount() async {
        await perform {
            try await self.supabase.rpc("delete_account").execute()
            await self.signOut()
        }
    }

    // MARK: - Links (convites e callback de email)
    func handle(url: URL) async {
        if let code = InviteLink.code(from: url) {
            if userId == nil {
                pendingInviteCode = code
                infoMessage = L("invite.loginFirst")
            } else {
                await join(code: code)
                updatePhase()
            }
            return
        }
        // Confirmação de email / recuperação de password
        await perform {
            try await self.supabase.auth.session(from: url)
        }
    }

    // MARK: - Perfil
    private func loadProfile(_ user: User) async {
        let profile: UserProfile? = try? await supabase
            .from("profiles").select("id,name").eq("id", value: user.id.uuidString)
            .single().execute().value
        if let name = profile?.name, !name.isEmpty {
            displayName = name
        } else if let metaName = (user.userMetadata["full_name"] ?? user.userMetadata["name"])?.stringValue,
                  !metaName.isEmpty {
            await saveName(metaName)
        }
    }

    func saveName(_ raw: String) async {
        let name = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard let uid = userId, !name.isEmpty else { return }
        await perform {
            try await self.supabase.from("profiles")
                .upsert(UserProfile(id: uid, name: name))
                .execute()
            self.displayName = name
            if let hid = self.currentHousehold?.id { await self.loadMembers(hid) }
        }
        updatePhase()
    }

    // MARK: - Listas
    private func loadHouseholds() async {
        do {
            households = try await supabase
                .from("households").select("id,name,invite_code")
                .order("created_at").execute().value
        } catch {
            print("[iList] loadHouseholds falhou: \(error)")
        }
        let savedId = UserDefaults.standard.string(forKey: currentHouseholdKey)
        let chosen = households.first { $0.id.uuidString == savedId } ?? households.first
        await select(chosen)
    }

    func select(_ household: Household?) async {
        currentHousehold = household
        UserDefaults.standard.set(household?.id.uuidString, forKey: currentHouseholdKey)
        members = []
        if let id = household?.id { await loadMembers(id) }
        updatePhase()
    }

    func reloadMembers() async {
        if let id = currentHousehold?.id { await loadMembers(id) }
    }

    private func loadMembers(_ householdId: UUID) async {
        do {
            members = try await supabase
                .rpc("household_member_list", params: ["p_household_id": householdId.uuidString])
                .execute().value
        } catch {
            print("[iList] loadMembers falhou: \(error)")
        }
    }

    func createHousehold(name raw: String) async {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        await perform {
            let household: Household = try await self.supabase
                .rpc("create_household", params: ["p_name": String(name.prefix(60))])
                .execute().value
            self.households.append(household)
            await self.select(household)
        }
    }

    func join(code raw: String) async {
        guard let code = InviteLink.normalize(raw) else {
            errorMessage = L("error.invalidCode")
            return
        }
        await perform {
            let household: Household = try await self.supabase
                .rpc("join_household", params: ["p_code": code])
                .execute().value
            if !self.households.contains(where: { $0.id == household.id }) {
                self.households.append(household)
            }
            await self.select(household)
            self.infoMessage = String(format: L("invite.joined"), household.name)
        }
    }

    func leaveCurrentHousehold() async {
        guard let hid = currentHousehold?.id else { return }
        await perform {
            try await self.supabase
                .rpc("leave_household", params: ["p_household_id": hid.uuidString])
                .execute()
            self.households.removeAll { $0.id == hid }
            await self.select(self.households.first)
        }
    }

    func rotateInviteCode() async {
        guard let hid = currentHousehold?.id else { return }
        await perform {
            let code: String = try await self.supabase
                .rpc("rotate_invite_code", params: ["p_household_id": hid.uuidString])
                .execute().value
            self.currentHousehold?.inviteCode = code
            if let i = self.households.firstIndex(where: { $0.id == hid }) {
                self.households[i].inviteCode = code
            }
        }
    }

    func remove(member: HouseholdMember) async {
        guard let hid = currentHousehold?.id else { return }
        await perform {
            try await self.supabase.from("household_members").delete()
                .eq("household_id", value: hid.uuidString)
                .eq("user_id", value: member.userId.uuidString)
                .execute()
            self.members.removeAll { $0.userId == member.userId }
        }
    }

    // MARK: - Bloqueio local
    func lockIfNeeded() {
        if KeychainService.shared.isLockEnabled && userId != nil { isLocked = true }
    }

    func unlock() { isLocked = false }

    // MARK: - Helpers
    /// Corre uma operação com indicador de trabalho e traduz o erro para uma mensagem legível.
    private func perform(_ operation: @MainActor () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String? {
        if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
            return nil
        }
        if (error as NSError).code == 1001, (error as NSError).domain == "com.apple.AuthenticationServices.AuthorizationError" {
            return nil   // Sign in with Apple cancelado
        }
        let text = String(describing: error).lowercased()
        if text.contains("invalid code") { return L("error.invalidCode") }
        if text.contains("invalid login credentials") { return L("error.wrongCredentials") }
        if text.contains("already registered") { return L("error.alreadyRegistered") }
        if text.contains("email not confirmed") { return L("error.emailNotConfirmed") }
        if text.contains("password should be") || text.contains("weak") { return L("error.weakPassword") }
        if error is URLError { return L("error.offline") }
        print("[iList] erro: \(error)")
        return L("error.generic")
    }
}
