import Foundation
import Security

/// Bloqueio opcional da app (PIN + Face ID / Touch ID), guardado só neste dispositivo.
/// É uma camada extra: quem identifica a pessoa é a conta, não o PIN.
class KeychainService {
    static let shared = KeychainService()
    private init() {}

    private let service = "com.davidarsenio.iList"
    private let pinAccount = "ilist_app_lock_pin"
    private let pinLengthKey = "app_lock_pin_length"
    private let biometricKey = "app_lock_biometric_enabled"

    // MARK: - PIN
    func savePIN(_ pin: String) {
        guard let data = pin.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pinAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getPIN() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pinAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Desliga o bloqueio: apaga PIN, tamanho e preferência de biometria.
    func deletePIN() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pinAccount
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: pinLengthKey)
        setBiometricEnabled(false)
    }

    var pinLength: Int {
        let v = UserDefaults.standard.integer(forKey: pinLengthKey)
        return v == 0 ? 6 : v
    }

    func setPINLength(_ length: Int) {
        UserDefaults.standard.set(length, forKey: pinLengthKey)
    }

    var isLockEnabled: Bool { getPIN() != nil }

    // MARK: - Biometric
    var isBiometricEnabled: Bool {
        UserDefaults.standard.bool(forKey: biometricKey)
    }

    func setBiometricEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: biometricKey)
    }
}
