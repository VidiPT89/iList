import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // A chave "publishable" é pública por natureza: a privacidade dos dados é garantida pelo RLS.
        client = SupabaseClient(
            supabaseURL: URL(string: "https://avifvauxtshneanzwudi.supabase.co")!,
            supabaseKey: "sb_publishable_J1EHIYUWZaSPObwbFcwetQ_KWyvakhK",
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    redirectToURL: AppConfig.authCallbackURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
