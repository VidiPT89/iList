import SwiftUI

struct AddItemView: View {
    @ObservedObject var listVM: ListViewModel
    let userName: String
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var category: ItemCategory = .outros
    @State private var quantity = ""
    @State private var unit = ""
    @FocusState private var nameFocused: Bool

    let units = ["", "un", "kg", "g", "L", "ml", "cx", "pct", "dz"]

    var body: some View {
        NavigationStack {
            Form {
                Section("item.product") {
                    TextField("item.product.placeholder", text: $name)
                        .focused($nameFocused)
                }

                Section("item.category") {
                    Picker("item.category", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Label(cat.localizedKey, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("item.quantity") {
                    HStack {
                        TextField("item.quantity.placeholder", text: $quantity)
                            .keyboardType(.decimalPad)
                        Divider()
                        Picker("item.unit", selection: $unit) {
                            ForEach(units, id: \.self) { u in
                                Text(u.isEmpty ? "—" : u).tag(u)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .navigationTitle("item.new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("item.add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            await listVM.addItem(
                                name: trimmed,
                                category: category,
                                quantity: quantity.isEmpty ? nil : quantity,
                                unit: unit.isEmpty ? nil : unit,
                                addedByName: userName
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { nameFocused = true }
        }
    }
}
