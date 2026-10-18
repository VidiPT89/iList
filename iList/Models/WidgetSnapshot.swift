import Foundation

/// Item resumido para o widget — nome + ícone da categoria, sem os restantes campos.
struct WidgetShoppingItem: Codable {
    let name: String
    let icon: String
}

/// Estado partilhado com a extensão de widget via App Group.
/// Escrito pela app principal (`ListViewModel`) sempre que a lista muda.
struct WidgetSnapshot: Codable {
    let items: [WidgetShoppingItem]
    let totalCount: Int
    let language: String

    static let userDefaultsKey = "widget.snapshot"

    /// Estado real de "sem dados ainda" (primeiro arranque, antes da app sincronizar).
    /// Nunca usar `.placeholder` como fallback de conteúdo real — só serve para a
    /// pré-visualização redacted da galeria de widgets (`placeholder(in:)`).
    static var empty: WidgetSnapshot {
        WidgetSnapshot(items: [], totalCount: 0, language: "pt-PT")
    }

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            items: [
                WidgetShoppingItem(name: "Leite", icon: "cup.and.saucer"),
                WidgetShoppingItem(name: "Pão", icon: "birthday.cake"),
                WidgetShoppingItem(name: "Detergente", icon: "bubbles.and.sparkles")
            ],
            totalCount: 3,
            language: "pt-PT"
        )
    }

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: AppConfig.appGroupId),
              let data = defaults.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Apaga o snapshot (ao terminar sessão) para o widget não mostrar a lista de outra conta.
    static func clear() {
        UserDefaults(suiteName: AppConfig.appGroupId)?.removeObject(forKey: userDefaultsKey)
    }

    /// Atualiza só o idioma do snapshot já guardado (sem precisar da lista de itens em
    /// memória) — usado quando o utilizador muda o idioma nas Definições, para o widget
    /// não ficar com o idioma antigo até à próxima alteração da lista.
    static func updateLanguage(_ language: String) {
        guard let defaults = UserDefaults(suiteName: AppConfig.appGroupId) else { return }
        let current = load() ?? .empty
        let updated = WidgetSnapshot(items: current.items, totalCount: current.totalCount, language: language)
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: userDefaultsKey)
    }
}
