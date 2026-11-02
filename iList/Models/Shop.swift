import Foundation

/// Supermercado com a ordem dos corredores (categorias), partilhado pela lista.
struct Store: Codable, Identifiable, Hashable {
    let id: UUID
    var householdId: UUID
    var name: String
    var categoryOrder: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case categoryOrder = "category_order"
    }

    /// Categorias pela ordem dos corredores; as que faltam vão para o fim pela ordem habitual.
    var orderedCategories: [ItemCategory] {
        Store.ordered(categoryOrder)
    }

    static func ordered(_ rawValues: [String]) -> [ItemCategory] {
        var known: [ItemCategory] = []
        for raw in rawValues {
            if let cat = ItemCategory(rawValue: raw), !known.contains(cat) { known.append(cat) }
        }
        return known + ItemCategory.allCases.filter { !known.contains($0) }
    }
}

struct StoreUpsert: Encodable {
    let id: UUID
    let householdId: UUID
    let name: String
    let categoryOrder: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case categoryOrder = "category_order"
    }
}

/// Uma compra terminada: o que custou, quem pagou e se já foi acertada.
struct Trip: Codable, Identifiable, Hashable {
    let id: UUID
    var storeName: String?
    var totalCents: Int?
    var paidBy: UUID?
    var paidByName: String?
    var itemCount: Int
    var settled: Bool
    var finishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storeName = "store_name"
        case totalCents = "total_cents"
        case paidBy = "paid_by"
        case paidByName = "paid_by_name"
        case itemCount = "item_count"
        case settled
        case finishedAt = "finished_at"
    }
}

/// Artigo comprado (histórico usado pela reposição).
struct Purchase: Codable, Hashable {
    let name: String
    let category: String
    let purchasedAt: Date

    enum CodingKeys: String, CodingKey {
        case name
        case category
        case purchasedAt = "purchased_at"
    }
}

// MARK: - Reposição

struct RestockSuggestion: Identifiable, Hashable {
    let name: String
    let category: ItemCategory
    /// Intervalo médio entre compras, em dias.
    let everyDays: Int
    var id: String { Restock.key(name) }
}

enum Restock {
    /// Mínimo de compras (em dias diferentes) para haver um ritmo fiável.
    static let minPurchases = 3

    static func key(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Artigos que costumam ser comprados com regularidade e cujo intervalo habitual já passou
    /// (ou quase), sem estarem na lista. Os mais atrasados vêm primeiro.
    static func suggestions(from purchases: [Purchase], excluding current: [ShoppingItem],
                            now: Date = Date(), limit: Int = 10) -> [RestockSuggestion] {
        let onList = Set(current.map { key($0.name) })
        let groups = Dictionary(grouping: purchases) { key($0.name) }
        let day: TimeInterval = 86_400

        var scored: [(RestockSuggestion, Double)] = []
        for (k, group) in groups where !onList.contains(k) {
            // Várias compras no mesmo dia contam como uma.
            var dates: [Date] = []
            for date in group.map(\.purchasedAt).sorted() {
                if let last = dates.last, date.timeIntervalSince(last) < day / 2 { continue }
                dates.append(date)
            }
            guard dates.count >= minPurchases, let first = dates.first, let last = dates.last else { continue }

            let average = last.timeIntervalSince(first) / Double(dates.count - 1)
            guard average >= day else { continue }
            let overdue = now.timeIntervalSince(last) / average
            guard overdue >= 0.85 else { continue }

            let latest = group.max { $0.purchasedAt < $1.purchasedAt }!
            let suggestion = RestockSuggestion(
                name: latest.name,
                category: ItemCategory(rawValue: latest.category) ?? .outros,
                everyDays: max(1, Int((average / day).rounded()))
            )
            scored.append((suggestion, overdue))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}

// MARK: - Despesas

/// Pagamento sugerido para acertar contas.
struct Settlement: Identifiable, Hashable {
    let from: HouseholdMember
    let to: HouseholdMember
    let cents: Int
    var id: String { "\(from.userId)-\(to.userId)" }
}

enum Expenses {
    /// Compras por acertar, com valor e pagador, divididas em partes iguais pelos membros atuais.
    /// Devolve o saldo de cada membro (positivo = tem a receber).
    static func balances(trips: [Trip], members: [HouseholdMember]) -> [UUID: Int] {
        guard !members.isEmpty else { return [:] }
        let open = trips.filter { !$0.settled && $0.totalCents != nil && $0.paidBy != nil }
        let total = open.reduce(0) { $0 + ($1.totalCents ?? 0) }
        let share = Double(total) / Double(members.count)

        var balances: [UUID: Int] = [:]
        for member in members {
            let paid = open.filter { $0.paidBy == member.userId }.reduce(0) { $0 + ($1.totalCents ?? 0) }
            balances[member.userId] = Int((Double(paid) - share).rounded())
        }
        return balances
    }

    /// Menos pagamentos possível: quem deve mais paga primeiro a quem tem mais a receber.
    static func settlements(trips: [Trip], members: [HouseholdMember]) -> [Settlement] {
        let balances = balances(trips: trips, members: members)
        var debtors = members.compactMap { m in balances[m.userId].flatMap { $0 < 0 ? (m, -$0) : nil } }
            .sorted { $0.1 > $1.1 }
        var creditors = members.compactMap { m in balances[m.userId].flatMap { $0 > 0 ? (m, $0) : nil } }
            .sorted { $0.1 > $1.1 }

        var result: [Settlement] = []
        var d = 0, c = 0
        while d < debtors.count && c < creditors.count {
            let amount = min(debtors[d].1, creditors[c].1)
            if amount > 0 {
                result.append(Settlement(from: debtors[d].0, to: creditors[c].0, cents: amount))
            }
            debtors[d].1 -= amount
            creditors[c].1 -= amount
            if debtors[d].1 == 0 { d += 1 }
            if creditors[c].1 == 0 { c += 1 }
        }
        // Arredondamentos de 1 cêntimo não contam.
        return result.filter { $0.cents > 1 }
    }

    static func format(cents: Int) -> String {
        let code = Locale.current.currency?.identifier ?? "EUR"
        return (Double(cents) / 100).formatted(.currency(code: code))
    }

    /// Lê um valor escrito pela pessoa ("23,45", "23.45", "23") em cêntimos.
    static func cents(from text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty, let value = Double(cleaned), value >= 0, value <= 100_000 else { return nil }
        return Int((value * 100).rounded())
    }
}
