import Foundation
import Supabase
import WidgetKit

@MainActor
class ListViewModel: ObservableObject {
    @Published var items: [ShoppingItem] = [] {
        didSet { syncWidget() }
    }
    @Published var isLoading = false
    @Published var syncFailed = false

    private var supabase: SupabaseClient { SupabaseService.shared.client }
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private(set) var householdId: UUID?

    /// Carrega a lista ativa. Ao trocar de lista, larga a subscrição e os itens da anterior.
    func load(householdId: UUID) async {
        if self.householdId != householdId {
            await stop()
            items = []
        }
        self.householdId = householdId
        await fetchItems()
        if realtimeChannel == nil {
            await subscribeToRealtime(householdId: householdId)
        }
    }

    func stop() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel = realtimeChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
        realtimeChannel = nil
    }

    func fetchItems() async {
        guard let hId = householdId else { return }
        isLoading = true
        do {
            let fetched: [ShoppingItem] = try await supabase
                .from("shopping_items")
                .select()
                .eq("household_id", value: hId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            items = fetched
            syncFailed = false
        } catch {
            print("[iList] fetchItems falhou: \(error)")
            syncFailed = true
        }
        isLoading = false
    }

    func addItem(name: String, category: ItemCategory, quantity: String?, unit: String?, addedByName: String?) async {
        // Optimistic local insert for immediate UI feedback (works even without Supabase)
        let tempId = UUID()
        let placeholderHId = householdId ?? UUID()
        let temp = ShoppingItem(id: tempId, householdId: placeholderHId, name: name,
                                category: category, quantity: quantity, unit: unit,
                                isChecked: false, addedByName: addedByName, createdAt: Date())
        items.insert(temp, at: 0)

        guard let hId = householdId else { return }

        let insert = ItemInsert(householdId: hId, name: name, category: category.rawValue,
                                quantity: quantity, unit: unit, addedByName: addedByName)
        do {
            try await supabase.from("shopping_items").insert(insert).execute()
            syncFailed = false
        } catch {
            // Mantém o item localmente — Supabase inacessível ou RLS bloqueou
            print("[iList] addItem falhou: \(error)")
            syncFailed = true
        }
    }

    func removeByName(_ name: String) async {
        if let item = items.first(where: { $0.name.lowercased() == name.lowercased() }) {
            await deleteItem(item)
        }
    }

    func toggleItem(_ item: ShoppingItem) async {
        do {
            try await supabase
                .from("shopping_items")
                .update(["is_checked": !item.isChecked])
                .eq("id", value: item.id.uuidString)
                .execute()
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].isChecked.toggle()
            }
        } catch {}
    }

    func deleteItem(_ item: ShoppingItem) async {
        do {
            try await supabase
                .from("shopping_items")
                .delete()
                .eq("id", value: item.id.uuidString)
                .execute()
            items.removeAll { $0.id == item.id }
        } catch {}
    }

    func clearChecked() async {
        let checked = items.filter { $0.isChecked }
        for item in checked { await deleteItem(item) }
    }

    /// Escreve os itens por comprar no App Group e pede à WidgetKit para atualizar o widget.
    private func syncWidget() {
        let unchecked = items.filter { !$0.isChecked }
        let widgetItems = unchecked.prefix(8).map {
            WidgetShoppingItem(name: $0.name, icon: $0.category.icon)
        }
        let language = UserDefaults.standard.string(forKey: "languagePreference") ?? "pt-PT"
        let snapshot = WidgetSnapshot(items: widgetItems, totalCount: unchecked.count, language: language)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: AppConfig.appGroupId)?.set(data, forKey: WidgetSnapshot.userDefaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "iListWidget")
    }

    private func subscribeToRealtime(householdId: UUID) async {
        let channel = supabase.realtimeV2.channel("shopping:\(householdId.uuidString)")
        realtimeChannel = channel
        let changes = channel.postgresChange(
            AnyAction.self, schema: "public", table: "shopping_items",
            filter: .eq("household_id", value: householdId)
        )
        try? await channel.subscribeWithError()
        realtimeTask = Task { [weak self] in
            for await _ in changes {
                await self?.fetchItems()
            }
        }
    }
}
