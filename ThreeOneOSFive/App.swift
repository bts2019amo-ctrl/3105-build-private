import SwiftUI



@main

struct ThreeOneOSFiveApp: App {
    
    @StateObject private var appState = AppState()
    
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    

    
    private var language: AppLanguage {
        
        AppLanguage(rawValue: languageCode) ?? .english
        
    }
    

    
    var body: some Scene {
        
        WindowGroup {
            
            ContentView()
            
                .environmentObject(appState)
            
                .environmentObject(patchDraftCoordinator)
            
                .environmentObject(fileOperationCoordinator)
            
                .environment(\.appLanguage, language)
            
                .environment(\.locale, language.locale)
            
                .onAppear {
                    
                    appState.detectSupport()
                    
                }
            
                .onOpenURL { url in
                            
                    patchDraftCoordinator.presentImport(url)
                            
                           }
            
        }
        
    }
    
}



@MainActor

class AppState: ObservableObject {
    
    @Published var exploitStatus: ExploitStatus = .notStarted
    
    @Published var unsupportedMessage: String?
    
    @Published private(set) var isSecurityCompromised = SecurityGuard.isCompromised
    
    @Published private(set) var isKeySessionInvalidated = false
    


@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(patchDraftCoordinator)
                .environmentObject(fileOperationCoordinator)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .onAppear {
                    appState.detectSupport()
                }
                .onOpenURL { url in
                    patchDraftCoordinator.presentImport(url)
                }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published private(set) var isSecurityCompromised = SecurityGuard.isCompromised
    @Published private(set) var isKeySessionInvalidated = false

    var isSupported: Bool { unsupportedMessage == nil && !isSecurityCompromised }

    func markKeySessionValid() {
        isKeySessionInvalidated = false
    }

    func invalidateKeySession() {
        UserDefaults.standard.removeObject(forKey: "proxy_access_key")
        UserDefaults.standard.removeObject(forKey: "proxy_days_left")
        UserDefaults.standard.removeObject(forKey: "proxy_key_expires_at")
        isKeySessionInvalidated = true
    }

    func revalidateStoredKey() {
        let key = UserDefaults.standard.string(forKey: "proxy_access_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            do {
                let result = try await KeyRevalidationService.validate(key)
                guard result.valid else {
                    await self?.invalidateKeySession()
                    return
                }
                let days = max(0, result.daysLeft ?? 0)
                await MainActor.run {
                    UserDefaults.standard.set(days, forKey: "proxy_days_left")
                    UserDefaults.standard.set(Date().addingTimeInterval(TimeInterval(days) * 86_400).timeIntervalSince1970, forKey: "proxy_key_expires_at")
                }
            } catch {
                // Falhas de rede não encerram a sessão; a próxima verificação tentará novamente.
            }
        }
    }

    func detectSupport() {
        isSecurityCompromised = SecurityGuard.isCompromised
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
        }
    }
}
