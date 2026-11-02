import SwiftUI

// MARK: - Terminar compra: loja, valor e quem pagou
struct FinishTripView: View {
    @EnvironmentObject var session: SessionViewModel
    @ObservedObject var shopVM: ShopViewModel
    @ObservedObject var listVM: ListViewModel
    let accentColor: Color
    @Environment(\.dismiss) var dismiss

    @State private var storeId: UUID?
    @State private var total = ""
    @State private var paidBy: UUID?
    @State private var saving = false

    private var cartCount: Int { listVM.items.filter(\.isChecked).count }
    private var totalCents: Int? { Expenses.cents(from: total) }
    private var totalIsInvalid: Bool { !total.trimmingCharacters(in: .whitespaces).isEmpty && totalCents == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill").foregroundStyle(accentColor)
                        Text(String(format: L("trip.cartCount"), cartCount))
                    }
                } footer: {
                    Text("trip.hint")
                }

                Section("trip.store") {
                    Picker("trip.store", selection: $storeId) {
                        Text("trip.store.none").tag(UUID?.none)
                        ForEach(shopVM.stores) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    TextField("trip.total.placeholder", text: $total)
                        .keyboardType(.decimalPad)
                    Picker("trip.paidBy", selection: $paidBy) {
                        ForEach(session.members) { member in
                            Text(member.displayName).tag(UUID?.some(member.userId))
                        }
                    }
                    .disabled(totalCents == nil)
                } header: {
                    Text("trip.total")
                } footer: {
                    Text(totalIsInvalid ? LocalizedStringKey("trip.total.invalid") : LocalizedStringKey("trip.total.hint"))
                        .foregroundStyle(totalIsInvalid ? .red : .secondary)
                }
            }
            .navigationTitle("trip.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("trip.finish") {
                        saving = true
                        Task {
                            let storeName = shopVM.stores.first { $0.id == storeId }?.name
                            let ok = await shopVM.finishTrip(
                                storeName: storeName,
                                totalCents: totalCents,
                                paidBy: totalCents == nil ? nil : paidBy
                            )
                            await listVM.fetchItems()
                            saving = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(saving || cartCount == 0 || totalIsInvalid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                storeId = shopVM.selectedStoreId
                paidBy = session.userId
            }
        }
    }
}

// MARK: - Despesas: acerto de contas e compras anteriores
struct ExpensesView: View {
    @EnvironmentObject var session: SessionViewModel
    @ObservedObject var shopVM: ShopViewModel
    let accentColor: Color
    @Environment(\.dismiss) var dismiss
    @State private var confirmSettle = false

    private var settlements: [Settlement] {
        Expenses.settlements(trips: shopVM.trips, members: session.members)
    }

    private var monthTotal: Int {
        let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        return shopVM.trips.filter { $0.finishedAt >= start }.reduce(0) { $0 + ($1.totalCents ?? 0) }
    }

    private var hasOpenTrips: Bool {
        shopVM.trips.contains { !$0.settled && $0.totalCents != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("expenses.month")
                        Spacer()
                        Text(Expenses.format(cents: monthTotal))
                            .font(.headline.monospacedDigit())
                    }
                }

                if session.members.count > 1 {
                    Section {
                        if settlements.isEmpty {
                            Label("expenses.even", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(accentColor)
                        } else {
                            ForEach(settlements) { s in
                                HStack(spacing: 10) {
                                    avatarView(name: s.from.displayName, color: s.from.color, size: 28)
                                    Text(String(format: L("expenses.owes"), s.from.displayName, s.to.displayName))
                                    Spacer()
                                    Text(Expenses.format(cents: s.cents))
                                        .font(.body.monospacedDigit().weight(.semibold))
                                }
                            }
                        }
                        if hasOpenTrips {
                            Button("expenses.settle") { confirmSettle = true }
                                .tint(accentColor)
                        }
                    } header: {
                        Text("expenses.balance")
                    } footer: {
                        Text("expenses.balance.hint")
                    }
                }

                Section("expenses.trips") {
                    if shopVM.trips.isEmpty {
                        Text("expenses.empty").foregroundStyle(.secondary)
                    }
                    ForEach(shopVM.trips) { trip in
                        TripRow(trip: trip)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await shopVM.deleteTrip(trip) }
                                } label: { Label("item.delete", systemImage: "trash") }
                            }
                    }
                }
            }
            .navigationTitle("expenses.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("catalog.close") { dismiss() }
                }
            }
            .alert("expenses.settle", isPresented: $confirmSettle) {
                Button("action.cancel", role: .cancel) {}
                Button("expenses.settle.action") { Task { await shopVM.settleAll() } }
            } message: {
                Text("expenses.settle.message")
            }
            .refreshable { await shopVM.fetchTrips() }
        }
        .task { await session.reloadMembers() }
    }
}

struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.storeName ?? L("trip.store.none"))
                    .font(.body.weight(.medium))
                HStack(spacing: 4) {
                    Text(trip.finishedAt.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text(String(format: L("trip.items"), trip.itemCount))
                    if let payer = trip.paidByName, trip.totalCents != nil {
                        Text("·")
                        Text(String(format: L("trip.paidByName"), payer))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if let cents = trip.totalCents {
                    Text(Expenses.format(cents: cents))
                        .font(.body.monospacedDigit().weight(.semibold))
                }
                if trip.settled {
                    Text("trip.settled").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .opacity(trip.settled ? 0.6 : 1)
    }
}

// MARK: - Sugestões de reposição (aparecem no topo da lista)
struct RestockStrip: View {
    let suggestions: [RestockSuggestion]
    let accentColor: Color
    let onAdd: (RestockSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("restock.title", systemImage: "sparkles")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions) { s in
                        Button { onAdd(s) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(accentColor)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(s.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(String(format: L("restock.every"), s.everyDays))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
    }
}
