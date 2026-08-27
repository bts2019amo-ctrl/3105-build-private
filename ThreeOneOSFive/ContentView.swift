import SwiftUI
import UIKit


struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true
    @AppStorage("proxy_access_key") private var proxyAccessKey = ""
    @AppStorage("proxy_key_expires_at") private var proxyKeyExpiresAt = 0.0
    @State private var clock = Date()


    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 4
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }


    var body: some View {
        Group {
            if appState.isSecurityCompromised {
                SecurityBlockedView()
            } else if appState.isKeySessionInvalidated || proxyAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isKeyExpired {
                ProxyLoginView()
            } else if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .background(AppBackgroundView().ignoresSafeArea())
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
        .task {
            appState.revalidateStoredKey()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let now = Date()
                clock = now

                if proxyKeyExpiresAt > 0 && proxyKeyExpiresAt <= now.timeIntervalSince1970 {
                    appState.invalidateKeySession()
                    continue
                }

                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                appState.revalidateStoredKey()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                clock = Date()
                appState.revalidateStoredKey()
            }
        }
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: cleanerEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
