import SwiftUI

// MARK: - Lista ativa: membros, convite, trocar/criar/entrar/sair
struct ListSettingsSection: View {
    @EnvironmentObject var session: SessionViewModel

    @State private var showNewList = false
    @State private var newListName = ""
    @State private var showJoin = false
    @State private var joinCode = ""
    @State private var showLeaveConfirm = false
    @State private var memberToRemove: HouseholdMember?

    var body: some View {
        if let household = session.currentHousehold {
            settingsCard(title: "settings.list") {
                VStack(alignment: .leading, spacing: 14) {
                    if session.households.count > 1 {
                        Picker("settings.list.active", selection: Binding(
                            get: { household.id },
                            set: { id in
                                Task { await session.select(session.households.first { $0.id == id }) }
                            }
                        )) {
                            ForEach(session.households) { Text($0.name).tag($0.id) }
                        }
                        .tint(session.myColor)
                        Divider()
                    } else {
                        Text(household.name).font(.headline)
                    }

                    membersList
                    Divider()
                    inviteBlock(household)
                    Divider()
                    actions
                }
            }
            .alert("settings.list.new", isPresented: $showNewList) {
                TextField("onboarding.list.namePlaceholder", text: $newListName)
                Button("action.cancel", role: .cancel) {}
                Button("onboarding.list.createButton") {
                    Task { await session.createHousehold(name: newListName); newListName = "" }
                }
            }
            .alert("settings.list.join", isPresented: $showJoin) {
                TextField("onboarding.list.codePlaceholder", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                Button("action.cancel", role: .cancel) {}
                Button("onboarding.list.joinButton") {
                    Task { await session.join(code: joinCode); joinCode = "" }
                }
            }
            .alert("settings.list.leave", isPresented: $showLeaveConfirm) {
                Button("action.cancel", role: .cancel) {}
                Button("settings.list.leaveAction", role: .destructive) {
                    Task { await session.leaveCurrentHousehold() }
                }
            } message: {
                Text(session.members.count <= 1 ? "settings.list.leave.lastMessage" : "settings.list.leave.message")
            }
            .alert("settings.list.removeMember", isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            ), presenting: memberToRemove) { member in
                Button("action.cancel", role: .cancel) {}
                Button("settings.list.removeAction", role: .destructive) {
                    Task { await session.remove(member: member) }
                }
            } message: { member in
                Text(String(format: L("settings.list.removeMessage"), member.displayName))
            }
        }
    }

    private var membersList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("settings.list.members")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(session.members) { member in
                HStack(spacing: 12) {
                    avatarView(name: member.displayName, color: member.color, size: 32)
                    Text(member.displayName)
                    if member.userId == session.userId {
                        Text("settings.list.you").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if member.isOwner {
                        Text("settings.list.owner").font(.caption).foregroundStyle(.secondary)
                    } else if session.isOwnerOfCurrent {
                        Button { memberToRemove = member } label: {
                            Image(systemName: "person.badge.minus").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func inviteBlock(_ household: Household) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.list.inviteHint")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(household.inviteCode)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                Spacer()
                if session.isOwnerOfCurrent {
                    Button { Task { await session.rotateInviteCode() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(Text("settings.list.newCode"))
                }
            }

            ShareLink(
                item: household.inviteURL,
                message: Text(String(format: L("invite.shareMessage"), household.name, household.inviteCode))
            ) {
                Label("settings.list.invite", systemImage: "person.badge.plus")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(session.myColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { showNewList = true } label: {
                Label("settings.list.new", systemImage: "plus.circle")
            }
            Button { showJoin = true } label: {
                Label("settings.list.join", systemImage: "person.2")
            }
            Button(role: .destructive) { showLeaveConfirm = true } label: {
                Label("settings.list.leave", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
        }
        .tint(session.myColor)
    }
}
