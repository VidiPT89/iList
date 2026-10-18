import CryptoKit
import Foundation
import Security

/// Nonce do Sign in with Apple: a Apple recebe o hash, o Supabase recebe o original e confirma que batem.
enum AppleNonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Código de convite a partir de um link (`https://ividi.dev/ilist/join?code=…` ou `ilist://join?code=…`).
enum InviteLink {
    static func code(from url: URL) -> String? {
        let isInvite = url.scheme == AppConfig.urlScheme
            ? url.host == "join"
            : url.absoluteString.hasPrefix(AppConfig.inviteBaseURL)
        guard isInvite,
              let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        return normalize(code)
    }

    /// Maiúsculas, sem espaços nem hífenes; códigos têm 8 caracteres.
    static func normalize(_ raw: String) -> String? {
        let code = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        return code.count == 8 ? code : nil
    }
}

/// Texto localizado segundo o idioma escolhido na app (não o do sistema).
func L(_ key: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "languagePreference") ?? "pt-PT"
    guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return NSLocalizedString(key, comment: "")
    }
    return bundle.localizedString(forKey: key, value: nil, table: nil)
}
