import SwiftUI

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    private var language: AppLanguage { AppLanguage(rawValue: languageCode) ?? .english }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(patchDraftCoordinator)
                .environmentObject(fileOperationCoordinator)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .onAppear { appState.detectSupport() }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published private(set) var isSecurityCompromised = SecurityGuard.isCompromised
    @Published private(set) var isKeySessionInvalidated = false
    @Published private(set) var isCheckingStoredKey = false
    private var revalidationInFlight = false

    init() {
        LicenseKeyStore.restoreToUserDefaults()
        let storedKey = UserDefaults.standard.string(forKey: "proxy_access_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "";
        isCheckingStoredKey = !storedKey.isEmpty
        isKeySessionInvalidated = !storedKey.isEmpty
    }

    var isSupported: Bool { unsupportedMessage == nil && !isSecurityCompromised }

    func markKeySessionValid() {
        isCheckingStoredKey = false
        isKeySessionInvalidated = false
    }

    func invalidateKeySession() {
        LicenseKeyStore.delete()
        let defaults = UserDefaults.standard;
        defaults.removeObject(forKey: "proxy_access_key")
        defaults.removeObject(forKey: "proxy_days_left")
        defaults.removeObject(forKey: "proxy_key_expires_at")
        defaults.removeObject(forKey: "proxy_key_expiration_anchor")
        isCheckingStoredKey = false
        isKeySessionInvalidated = true
    }

    func revalidateStoredKey(isInitial: Bool = false) {
        guard !revalidationInFlight else { return }
        let key = UserDefaults.standard.string(forKey: "proxy_access_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            isCheckingStoredKey = false
            return
        }

        if isInitial {
            isCheckingStoredKey = true
            isKeySessionInvalidated = true
        }
        revalidationInFlight = true
        Task { [weak self] in
            defer {
                self?.revalidationInFlight = false
                if isInitial { self?.isCheckingStoredKey = false }
            }
            do {
                let result = try await KeyRevalidationService.validate(key)
                guard let self else { return }

                // Ignore a response that belongs to a session already replaced by another key.
                let currentKey = UserDefaults.standard.string(forKey: "proxy_access_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard currentKey == key else { return }

                guard result.valid else {
                    self.invalidateKeySession()
                    return
                }

                let defaults = UserDefaults.standard
                let days = max(0, result.daysLeft ?? 0)
                defaults.set(days, forKey: "proxy_days_left")

                // `daysLeft` is rounded by the API. Anchor the local countdown only
                // once for this key; periodic revalidation must never reset the clock.
                let anchorKey = "proxy_key_expiration_anchor"
                let existingAnchor = defaults.string(forKey: anchorKey)
                let existingExpiration = defaults.double(forKey: "proxy_key_expires_at")
                if existingAnchor != key || existingExpiration <= 0 {
                    let expiration = Date().addingTimeInterval(TimeInterval(days) * 86_400).timeIntervalSince1970
                    defaults.set(expiration, forKey: "proxy_key_expires_at")
                    defaults.set(key, forKey: anchorKey)
                }
                let persistedExpiration = defaults.double(forKey: "proxy_key_expires_at")
                _ = LicenseKeyStore.save(key: key, expiresAt: persistedExpiration, daysLeft: days)
                self.markKeySessionValid()
            } catch {
                // Na abertura, a falha de validação mantém o app no login com a key preenchida.
                if isInitial { self?.isKeySessionInvalidated = true }
            }
        }
    }

    func detectSupport() {
        isSecurityCompromised = SecurityGuard.isCompromised
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(major: v.major, minor: v.minor, patch: v.patch, build: AppInfo.osBuild)
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif
        unsupportedMessage = supported ? nil : "iOS (AppInfo.osVersion) ((AppInfo.osBuild))"
        if let unsupportedMessage { exploitStatus = .unsupported(unsupportedMessage) }
    }
}
