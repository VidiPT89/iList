import Foundation
import Supabase

/// Lojas, compras terminadas e histórico da lista ativa.
@MainActor
final class ShopViewModel: ObservableObject {
    @Published private(set) var stores: [Store] = []
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var purchases: [Purchase] = []
    @Published var selectedStoreId: UUID? {
        didSet {
            guard let hId = householdId else { return }
            UserDefaults.standard.set(selectedStoreId?.uuidString, forKey: storeKey(hId))
        }
    }
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseService.shared.client }
    private(set) var householdId: UUID?

    var selectedStore: Store? { stores.first { $0.id == selectedStoreId } }

    private func storeKey(_ hId: UUID) -> String { "selectedStore.\(hId.uuidString)" }

    func load(householdId: UUID) async {
        if self.householdId != householdId {
            stores = []; trips = []; purchases = []
        }
        self.householdId = householdId
        async let s: Void = fetchStores()
        async let t: Void = fetchTrips()
        async let p: Void = fetchPurchases()
        _ = await (s, t, p)

        let saved = UserDefaults.standard.string(forKey: storeKey(householdId))
        selectedStoreId = stores.first { $0.id.uuidString == saved }?.id
    }

    func fetchStores() async {
        guard let hId = householdId else { return }
        do {
            stores = try await supabase.from("stores")
                .select("id,household_id,name,category_order")
                .eq("household_id", value: hId.uuidString)
                .order("created_at").execute().value
        } catch {
            print("[iList] fetchStores falhou: \(error)")
        }
    }

    func fetchTrips() async {
        guard let hId = householdId else { return }
        do {
            trips = try await supabase.from("trips")
                .select("id,store_name,total_cents,paid_by,paid_by_name,item_count,settled,finished_at")
                .eq("household_id", value: hId.uuidString)
                .order("finished_at", ascending: false)
                .limit(200).execute().value
        } catch {
            print("[iList] fetchTrips falhou: \(error)")
        }
    }

    /// Último ano de compras: chega para perceber o ritmo de cada artigo.
    func fetchPurchases() async {
        guard let hId = householdId else { return }
        let since = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        do {
            purchases = try await supabase.from("purchases")
                .select("name,category,purchased_at")
                .eq("household_id", value: hId.uuidString)
                .gte("purchased_at", value: since.ISO8601Format())
                .order("purchased_at", ascending: false)
                .limit(3000).execute().value
        } catch {
            print("[iList] fetchPurchases falhou: \(error)")
        }
    }

    // MARK: - Lojas
    func saveStore(id: UUID?, name raw: String, order: [ItemCategory]) async {
        guard let hId = householdId else { return }
        let name = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !name.isEmpty else { return }
        let store = StoreUpsert(id: id ?? UUID(), householdId: hId, name: name,
                                categoryOrder: order.map(\.rawValue))
        do {
            try await supabase.from("stores").upsert(store).execute()
            await fetchStores()
            if id == nil { selectedStoreId = store.id }
        } catch {
            fail(error)
        }
    }

    func deleteStore(_ store: Store) async {
        do {
            try await supabase.from("stores").delete().eq("id", value: store.id.uuidString).execute()
            stores.removeAll { $0.id == store.id }
            if selectedStoreId == store.id { selectedStoreId = nil }
        } catch {
            fail(error)
        }
    }

    // MARK: - Compras
    /// Guarda a compra e o histórico; os artigos no carrinho saem da lista (no servidor, de uma vez).
    func finishTrip(storeName: String?, totalCents: Int?, paidBy: UUID?) async -> Bool {
        guard let hId = householdId else { return false }
        struct Params: Encodable {
            let p_household_id: UUID
            let p_store_name: String?
            let p_total_cents: Int?
            let p_paid_by: UUID?
        }
        do {
            try await supabase.rpc("finish_trip", params: Params(
                p_household_id: hId, p_store_name: storeName,
                p_total_cents: totalCents, p_paid_by: paidBy
            )).execute()
            async let t: Void = fetchTrips()
            async let p: Void = fetchPurchases()
            _ = await (t, p)
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// Marca como acertadas todas as compras em aberto.
    func settleAll() async {
        guard let hId = householdId else { return }
        do {
            try await supabase.from("trips").update(["settled": true])
                .eq("household_id", value: hId.uuidString)
                .eq("settled", value: false)
                .execute()
            await fetchTrips()
        } catch {
            fail(error)
        }
    }

    func deleteTrip(_ trip: Trip) async {
        do {
            try await supabase.from("trips").delete().eq("id", value: trip.id.uuidString).execute()
            trips.removeAll { $0.id == trip.id }
            await fetchPurchases()
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        print("[iList] erro: \(error)")
        errorMessage = error is URLError ? L("error.offline") : L("error.generic")
    }
}
