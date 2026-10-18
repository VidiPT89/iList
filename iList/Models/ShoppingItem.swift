import Foundation
import SwiftUI

struct ShoppingItem: Identifiable, Codable, Equatable {
    let id: UUID
    var householdId: UUID
    var name: String
    var category: ItemCategory
    var quantity: String?
    var unit: String?
    var isChecked: Bool
    var addedBy: UUID?
    var addedByName: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case category
        case quantity
        case unit
        case isChecked = "is_checked"
        case addedBy = "added_by"
        case addedByName = "added_by_name"
        case createdAt = "created_at"
    }
}

/// Payload de inserção. `added_by` é preenchido pelo Supabase (default `auth.uid()`).
struct ItemInsert: Encodable {
    let householdId: UUID
    let name: String
    let category: String
    let quantity: String?
    let unit: String?
    let addedByName: String?

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case name
        case category
        case quantity
        case unit
        case addedByName = "added_by_name"
    }
}

enum ItemCategory: String, Codable, CaseIterable {
    case carnePeixe = "Carne & Peixe"
    case vegetaisFruta = "Vegetais & Fruta"
    case laticinios = "Laticínios"
    case padaria = "Padaria"
    case conservasSecos = "Conservas & Secos"
    case limpeza = "Limpeza"
    case higiene = "Higiene"
    case bebidas = "Bebidas"
    case snacks = "Snacks"
    case congelados = "Congelados"
    case bebeCrianca = "Bebé & Criança"
    case animais = "Animais"
    case casa = "Casa"
    case outros = "Outros"

    /// Chave de localização — corresponde a "cat.<caseName>" em Localizable.strings.
    var localizedKey: LocalizedStringKey {
        // Concatenar uma String: a interpolação num LocalizedStringKey geraria a chave "cat.%@".
        LocalizedStringKey("cat." + String(describing: self))
    }

    var icon: String {
        switch self {
        case .carnePeixe: return "fork.knife"
        case .vegetaisFruta: return "leaf"
        case .laticinios: return "cup.and.saucer"
        case .padaria: return "birthday.cake"
        case .conservasSecos: return "archivebox"
        case .limpeza: return "bubbles.and.sparkles"
        case .higiene: return "drop"
        case .bebidas: return "wineglass"
        case .snacks: return "popcorn"
        case .congelados: return "snowflake"
        case .bebeCrianca: return "figure.and.child.holdinghands"
        case .animais: return "pawprint"
        case .casa: return "house"
        case .outros: return "shippingbox"
        }
    }
}
