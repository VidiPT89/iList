import SwiftUI

struct CatalogView: View {
    @ObservedObject var listVM: ListViewModel
    let accentColor: Color
    let userName: String
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var expandedCategories: Set<ItemCategory> = []
    @State private var pendingItem: CatalogItem?

    // Filtered catalog grouped by category
    private var filtered: [ItemCategory: [CatalogItem]] {
        let query = searchText.trimmingCharacters(in: .whitespaces).searchNormalized
        var result: [ItemCategory: [CatalogItem]] = [:]
        for cat in ItemCategory.allCases {
            let items = CatalogData.all
                .filter { $0.category == cat }
                .filter { query.isEmpty || $0.name.searchNormalized.contains(query) }
            if !items.isEmpty { result[cat] = items }
        }
        return result
    }

    private var totalSelected: Int {
        listVM.items.filter { !$0.isChecked }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                Divider()

                if filtered.isEmpty {
                    emptySearch
                } else {
                    catalogList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("catalog.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("catalog.close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if totalSelected > 0 {
                        Text(String(format: L("catalog.selectedCount"), totalSelected))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.15))
                            .foregroundStyle(accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .sheet(item: $pendingItem) { item in
                CatalogQuantitySheet(item: item, accentColor: accentColor) { qty, unit in
                    Task {
                        await listVM.addItem(
                            name: item.name,
                            category: item.category,
                            quantity: qty,
                            unit: unit,
                            addedByName: userName
                        )
                    }
                }
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
    }

    // MARK: Search bar
    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))

            TextField("catalog.search", text: $searchText)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: Main list
    var catalogList: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    if let catItems = filtered[cat] {
                        Section {
                            if expandedCategories.contains(cat) {
                                VStack(spacing: 0) {
                                    ForEach(catItems) { item in
                                        CatalogRow(
                                            item: item,
                                            isInList: isInList(item),
                                            accentColor: accentColor
                                        ) {
                                            toggle(item)
                                        }

                                        if item != catItems.last {
                                            Divider().padding(.leading, 52)
                                        }
                                    }
                                }
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, 16)
                            }
                        } header: {
                            categoryHeader(cat, count: catItems.count)
                        }
                    }
                }
                Spacer().frame(height: 20)
            }
            .padding(.top, 4)
        }
    }

    // MARK: Category header
    func categoryHeader(_ cat: ItemCategory, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedCategories.contains(cat) {
                    expandedCategories.remove(cat)
                } else {
                    expandedCategories.insert(cat)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: cat.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(cat.localizedKey)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Count of items in list for this category
                let inList = listVM.items.filter { $0.category == cat && !$0.isChecked }.count
                if inList > 0 {
                    Text("\(inList)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(accentColor)
                        .clipShape(Circle())
                }

                Image(systemName: expandedCategories.contains(cat)
                      ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: Empty search
    var emptySearch: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(accentColor.opacity(0.4))
            Text(String(format: L("catalog.noResults"), searchText))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: Logic
    private func isInList(_ item: CatalogItem) -> Bool {
        listVM.items.contains {
            $0.name.lowercased() == item.name.lowercased() && !$0.isChecked
        }
    }

    private func toggle(_ item: CatalogItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if isInList(item) {
            Task { await listVM.removeByName(item.name) }
        } else {
            pendingItem = item   // mostra o sheet de quantidade
        }
    }
}

// MARK: - Catalog Quantity Sheet
struct CatalogQuantitySheet: View {
    let item: CatalogItem
    let accentColor: Color
    let onAdd: (String, String?) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var quantity = 1
    @State private var selectedUnit = "un."

    private let units = ["un.", "kg", "g", "L", "mL", "pct.", "cx.", "dz."]

    var body: some View {
        VStack(spacing: 0) {

            // Item header
            HStack(spacing: 14) {
                Image(systemName: item.category.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 38, height: 38)
                    .background(accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.category.localizedKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)

            // Quantity stepper
            HStack(spacing: 36) {
                Button {
                    if quantity > 1 {
                        quantity -= 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(quantity > 1 ? accentColor : Color(.systemGray3))
                        .frame(width: 48, height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(quantity)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .frame(minWidth: 60)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.2), value: quantity)

                Button {
                    quantity += 1
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 48, height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 22)

            // Unit picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(units, id: \.self) { unit in
                        Button {
                            selectedUnit = unit
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(unit)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(selectedUnit == unit ? accentColor : Color(.systemGray5))
                                .foregroundStyle(selectedUnit == unit ? .white : .secondary)
                                .clipShape(Capsule())
                                .animation(.easeInOut(duration: 0.15), value: selectedUnit)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 22)

            // Add button
            Button {
                let unit: String? = selectedUnit == "un." ? nil : selectedUnit
                onAdd("\(quantity)", unit)
                dismiss()
            } label: {
                Text("catalog.addToList")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Catalog Row
struct CatalogRow: View {
    let item: CatalogItem
    let isInList: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(isInList ? accentColor : Color.clear)
                        .frame(width: 26, height: 26)
                    Circle()
                        .strokeBorder(
                            isInList ? accentColor : Color(.systemGray3),
                            lineWidth: 2
                        )
                        .frame(width: 26, height: 26)
                    if isInList {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isInList)

                Text(item.name)
                    .font(.body)
                    .foregroundStyle(isInList ? accentColor : .primary)
                    .animation(.easeInOut(duration: 0.15), value: isInList)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
