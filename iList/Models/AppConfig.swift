import Foundation

/// Configuração central da app (partilhada com a extensão de widget).
enum AppConfig {
    /// Partilhado entre a app e a extensão de widget (WidgetKit) para trocar dados via UserDefaults.
    static let appGroupId = "group.com.davidarsenio.iList"

    /// Esquema de URL da app: callback de login (OAuth / confirmação de email) e convites `ilist://join?code=…`.
    static let urlScheme = "ilist"
    static let authCallbackURL = URL(string: "ilist://login-callback")!

    /// Página pública dos convites: abre a app se estiver instalada, senão explica como a instalar.
    static let inviteBaseURL = "https://ividi.dev/ilist/join"
    static let privacyPolicyURL = URL(string: "https://ividi.dev/ilist/privacy")!
}
