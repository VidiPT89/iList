import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ShoppingEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Timeline Provider

struct ShoppingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoppingEntry {
        ShoppingEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingEntry) -> Void) {
        completion(ShoppingEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingEntry>) -> Void) {
        let entry = ShoppingEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .empty)
        // A app pede um reload explícito (WidgetCenter) sempre que a lista muda;
        // este refresh periódico é só uma rede de segurança.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Strings (bilingues, sem depender do bundle da app principal)

private enum WidgetStrings {
    static func title(_ lang: String) -> String { lang == "en" ? "iList" : "iList" }
    static func toBuy(_ lang: String) -> String { lang == "en" ? "to buy" : "por comprar" }
    static func allDone(_ lang: String) -> String { lang == "en" ? "All done! 🎉" : "Tudo comprado! 🎉" }
    static func more(_ count: Int, _ lang: String) -> String {
        lang == "en" ? "+\(count) more" : "+\(count) mais"
    }
}

// MARK: - View

struct iListWidgetEntryView: View {
    var entry: ShoppingEntry
    @Environment(\.widgetFamily) var family

    private var lang: String { entry.snapshot.language }
    private var maxItems: Int { family == .systemMedium ? 6 : 3 }
    private var visibleItems: [WidgetShoppingItem] { Array(entry.snapshot.items.prefix(maxItems)) }
    private var overflow: Int { max(0, entry.snapshot.totalCount - visibleItems.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                Text("\(entry.snapshot.totalCount) \(WidgetStrings.toBuy(lang))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if visibleItems.isEmpty {
                Spacer()
                Text(WidgetStrings.allDone(lang))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleItems, id: \.name) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 16)
                            Text(item.name)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                    }
                    if overflow > 0 {
                        Text(WidgetStrings.more(overflow, lang))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

// MARK: - Widget

struct iListWidget: Widget {
    let kind: String = "iListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShoppingProvider()) { entry in
            iListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("iList")
        .description("Vê o que falta comprar sem abrir a app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    iListWidget()
} timeline: {
    ShoppingEntry(date: .now, snapshot: .placeholder)
}
