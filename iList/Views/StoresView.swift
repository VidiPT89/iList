import SwiftUI

// MARK: - Lojas da lista (percurso pelos corredores)
struct StoresView: View {
    @ObservedObject var shopVM: ShopViewModel
    let accentColor: Color
    @Environment(\.dismiss) var dismiss

    @State private var editing: Store?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(shopVM.stores) { store in
                        Button { editing = store } label: {
                            HStack {
                                Image(systemName: "storefront").foregroundStyle(accentColor)
                                Text(store.name).foregroundStyle(.primary)
                                Spacer()
                                if store.id == shopVM.selectedStoreId {
                                    Image(systemName: "checkmark").foregroundStyle(accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { shopVM.stores[$0] }
                        Task { for store in toDelete { await shopVM.deleteStore(store) } }
                    }

                    Button { creating = true } label: {
                        Label("stores.add", systemImage: "plus.circle.fill")
                    }
                    .tint(accentColor)
                } footer: {
                    Text("stores.footer")
                }
            }
            .navigationTitle("stores.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("catalog.close") { dismiss() }
                }
            }
            .sheet(item: $editing) { store in
                StoreEditorView(shopVM: shopVM, store: store, accentColor: accentColor)
            }
            .sheet(isPresented: $creating) {
                StoreEditorView(shopVM: shopVM, store: nil, accentColor: accentColor)
            }
        }
    }
}

// MARK: - Criar / editar loja: nome + ordem dos corredores
struct StoreEditorView: View {
    @ObservedObject var shopVM: ShopViewModel
    let store: Store?
    let accentColor: Color
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var order: [ItemCategory]

    init(shopVM: ShopViewModel, store: Store?, accentColor: Color) {
        self.shopVM = shopVM
        self.store = store
        self.accentColor = accentColor
        _name = State(initialValue: store?.name ?? "")
        _order = State(initialValue: store?.orderedCategories ?? ItemCategory.allCases)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section("stores.name") {
                    TextField("stores.name.placeholder", text: $name)
                }

                Section {
                    ForEach(Array(order.enumerated()), id: \.element) { index, cat in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(accentColor)
                                .clipShape(Circle())
                            Image(systemName: cat.icon).foregroundStyle(.secondary)
                            Text(cat.localizedKey)
                        }
                    }
                    .onMove { order.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("stores.route")
                } footer: {
                    Text("stores.route.hint")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(store == nil ? LocalizedStringKey("stores.new") : LocalizedStringKey("stores.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        Task {
                            await shopVM.saveStore(id: store?.id, name: trimmedName, order: order)
                            dismiss()
                        }
                    }
                    .disabled(trimmedName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
