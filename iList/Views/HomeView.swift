import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: SessionViewModel
    let household: Household
    @StateObject private var listVM = ListViewModel()
    @State private var showCatalog = false
    @State private var showAddItem = false
    @State private var showSettings = false
    @State private var selectedCategory: ItemCategory?

    private var accent: Color { session.myColor }

    private var allItems: [ShoppingItem] {
        guard let cat = selectedCategory else { return listVM.items }
        return listVM.items.filter { $0.category == cat }
    }
    private var unchecked: [ShoppingItem] { allItems.filter { !$0.isChecked } }
    private var checked:   [ShoppingItem] { allItems.filter  {  $0.isChecked } }
    private var hasChecked: Bool { listVM.items.contains { $0.isChecked } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if listVM.syncFailed {
                    syncFailedBanner
                }
                categoryBar
                Divider()

                if listVM.isLoading && listVM.items.isEmpty {
                    Spacer()
                    ProgressView("A carregar…")
                    Spacer()
                } else if listVM.items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }

            addButton
        }
        .sheet(isPresented: $showCatalog) {
            CatalogView(listVM: listVM, accentColor: accent, userName: session.displayName)
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(listVM: listVM, userName: session.displayName)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(session)
        }
        .task(id: household.id) {
            selectedCategory = nil
            await listVM.load(householdId: household.id)
        }
    }

    // MARK: Header
    var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("iList")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                householdSwitcher
            }

            Spacer()

            HStack(spacing: 16) {
                if hasChecked {
                    Button {
                        Task { await listVM.clearChecked() }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }

                Button { showSettings = true } label: {
                    avatarView(name: session.displayName, color: accent, size: 38)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }

    /// Nome da lista ativa; com várias listas, toca para trocar.
    @ViewBuilder
    var householdSwitcher: some View {
        if session.households.count > 1 {
            Menu {
                ForEach(session.households) { h in
                    Button {
                        Task { await session.select(h) }
                    } label: {
                        if h.id == household.id { Label(h.name, systemImage: "checkmark") } else { Text(h.name) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(household.name)
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } else {
            Text(household.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Sync failed banner
    var syncFailedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("home.syncFailed")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: Category chips
    var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "home.all", icon: "list.bullet", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    chip(label: cat.localizedKey, icon: cat.icon, selected: selectedCategory == cat) {
                        selectedCategory = (selectedCategory == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    func chip(label: LocalizedStringKey, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(selected ? accent : Color(.systemGray5))
            .foregroundStyle(selected ? .white : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Item list
    var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                if !unchecked.isEmpty {
                    Section {
                        ForEach(unchecked) { item in
                            ItemRow(item: item, accentColor: accent) {
                                Task { await listVM.toggleItem(item) }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await listVM.deleteItem(item) }
                                } label: { Label("item.delete", systemImage: "trash") }
                            }

                            Divider().padding(.leading, 58)
                        }
                    } header: {
                        sectionHeader("home.section.tobuy", count: unchecked.count)
                    }
                }

                if !checked.isEmpty {
                    Section {
                        ForEach(checked) { item in
                            ItemRow(item: item, accentColor: accent) {
                                Task { await listVM.toggleItem(item) }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await listVM.deleteItem(item) }
                                } label: { Label("item.delete", systemImage: "trash") }
                            }

                            Divider().padding(.leading, 58)
                        }
                    } header: {
                        sectionHeader("home.section.incart", count: checked.count)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    func sectionHeader(_ title: LocalizedStringKey, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
            Text("(\(count))")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Empty state
    var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 64))
                .foregroundStyle(accent.opacity(0.35))

            VStack(spacing: 6) {
                Text("home.empty.title")
                    .font(.title3.weight(.semibold))
                Text("home.empty.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: FABs
    var addButton: some View {
        VStack(spacing: 12) {
            // Secondary: custom item
            Button { showAddItem = true } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
            .buttonStyle(.plain)

            // Primary: catalog
            Button { showCatalog = true } label: {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(accent)
                    .clipShape(Circle())
                    .shadow(color: accent.opacity(0.45), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 36)
    }
}

// MARK: - Item Row
struct ItemRow: View {
    let item: ShoppingItem
    let accentColor: Color
    let onToggle: () -> Void

    /// Mesma cor que a pessoa tem noutros sítios (pelo id; itens antigos só têm o nome).
    private var addedByColor: Color {
        MemberColor.color(for: item.addedBy?.uuidString ?? item.addedByName ?? "")
    }

    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(item.isChecked ? accentColor : Color.clear)
                        .frame(width: 26, height: 26)
                    Circle()
                        .strokeBorder(
                            item.isChecked ? accentColor : Color(.systemGray3),
                            lineWidth: 2
                        )
                        .frame(width: 26, height: 26)
                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Name + meta
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)

                HStack(spacing: 5) {
                    Image(systemName: item.category.icon).font(.caption2)
                    Text(item.category.localizedKey).font(.caption)
                    if let q = item.quantity, !q.isEmpty {
                        Text("·").font(.caption).foregroundStyle(.tertiary)
                        Text(q + (item.unit.map { " \($0)" } ?? "")).font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Who added it
            if let name = item.addedByName, !name.isEmpty {
                avatarView(name: name, color: addedByColor, size: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}
