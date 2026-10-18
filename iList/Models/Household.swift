import SwiftUI

/// Uma lista partilhada. Só os membros a conseguem ler (RLS no Supabase).
struct Household: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var inviteCode: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode = "invite_code"
    }

    var inviteURL: URL {
        URL(string: "\(AppConfig.inviteBaseURL)?code=\(inviteCode)")!
    }
}

/// Membro de uma lista, devolvido pela RPC `household_member_list` (sem email).
struct HouseholdMember: Codable, Identifiable, Hashable {
    let userId: UUID
    let name: String?
    let role: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case role
    }

    var id: UUID { userId }
    var isOwner: Bool { role == "owner" }
    var displayName: String { name ?? "?" }
    var color: Color { MemberColor.color(for: userId.uuidString) }
}

/// Perfil do próprio utilizador (tabela `profiles`).
struct UserProfile: Codable {
    let id: UUID
    var name: String?
}

/// Cor estável por pessoa (o `hashValue` do Swift muda a cada arranque, por isso não serve).
enum MemberColor {
    static let palette: [Color] = [
        Color(red: 0.76, green: 0.58, blue: 0.22),   // amarelo torrado
        Color(red: 0.55, green: 0.72, blue: 0.44),   // verde-sage
        Color(red: 0.36, green: 0.55, blue: 0.80),   // azul
        Color(red: 0.80, green: 0.42, blue: 0.40),   // terracota
        Color(red: 0.58, green: 0.45, blue: 0.75),   // lilás
        Color(red: 0.30, green: 0.65, blue: 0.65),   // azul-petróleo
    ]

    static func color(for key: String) -> Color {
        let sum = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[sum % palette.count]
    }
}

// MARK: - Avatar (iniciais + cor da pessoa)
func avatarView(name: String, color: Color, size: CGFloat) -> some View {
    ZStack {
        Circle().fill(color)
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
}
