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
    @AppStorage(AppTheme.accentColorStorageKey) private var accentColorHex = AppTheme.defaultAccentHex
    @State private var clock = Date()
    @State private var hasPassedPreLogin = false
    @State private var isCharging = false

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
            } else if !isCharging {
                PreLoginPasswordsView {
                    withAnimation(.easeOut(duration: 0.18)) {
                        hasPassedPreLogin = true
                    }
                }
            } else if appState.isCheckingStoredKey {
                KeyValidationView()
            } else if needsLogin {
                ProxyLoginView()
            } else if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(Color(hex: accentColorHex))
        .imageScale(.small)
        .background(AppBackgroundView().ignoresSafeArea())
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
        .onAppear(perform: startBatteryMonitoring)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            updatePreLoginRoute()
        }
        .onChange(of: needsLogin) { _ in
            updatePreLoginRoute()
        }
        .onChange(of: appState.isCheckingStoredKey) { _ in
            updatePreLoginRoute()
        }
        .task {
            if isCharging {
                appState.revalidateStoredKey(isInitial: true)
            }
            var secondsSinceRevalidation = 0
            var secondsSinceThemeRefresh = 0

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }

                let now = Date()
                clock = now
                secondsSinceRevalidation += 1
                secondsSinceThemeRefresh += 1

                if secondsSinceThemeRefresh >= 2 && isCharging && !needsLogin {
                    secondsSinceThemeRefresh = 0
                    try? await PatchRemoteSync.synchronizeTheme()
                }

                if proxyKeyExpiresAt > 0 && proxyKeyExpiresAt <= now.timeIntervalSince1970 {
                    appState.invalidateKeySession()
                    secondsSinceRevalidation = 0
                    continue
                }

                if secondsSinceRevalidation >= 5 {
                    secondsSinceRevalidation = 0
                    if isCharging {
                        appState.revalidateStoredKey()
                    }
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                clock = Date()
                if isCharging {
                    appState.revalidateStoredKey()
                }
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
        }
        .onChange(of: wallpapersEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach([AppSection.home, AppSection.patches], id: \.self) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach([AppSection.home, AppSection.patches], id: \.self) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(AppSection(rawValue: tabNavigation.selectedTab) ?? .home)
                .id(tabNavigation.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                now: clock,
                cleanerEnabled: $cleanerEnabled,
                wallpapersEnabled: $wallpapersEnabled
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession
            )
        case .patches:
            GameSelectionView()
        case .cleaner:
            CleanerView()
        case .wallpapers:
            WallpaperLabView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var isKeyExpired: Bool {
        proxyKeyExpiresAt > 0 && proxyKeyExpiresAt <= clock.timeIntervalSince1970
    }

    private var needsLogin: Bool {
        appState.isKeySessionInvalidated ||
        proxyAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        isKeyExpired
    }

    private var chargerIsConnected: Bool {
        switch UIDevice.current.batteryState {
        case .charging:
            return true
        case .full, .unplugged, .unknown:
            return false
        @unknown default:
            return false
        }
    }

    private func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updatePreLoginRoute()
    }

    private func updatePreLoginRoute() {
        let charging = chargerIsConnected
        isCharging = charging
        guard !appState.isCheckingStoredKey else { return }
        hasPassedPreLogin = needsLogin && charging
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(
            cleanerEnabled: cleanerEnabled,
            wallpapersEnabled: wallpapersEnabled
        )
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .patches: return "tab.patches"
        case .cleaner: return "tab.cleaner"
        case .wallpapers: return "tab.wallpapers"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "folder.fill"
        case .patches: return "shippingbox.fill"
        case .cleaner: return "sparkles"
        case .wallpapers: return "photo.on.rectangle.angled.fill"
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("proxy_access_key") private var proxyAccessKey = ""
    @AppStorage("proxy_days_left") private var proxyDaysLeft = 0
    @AppStorage("proxy_key_expires_at") private var proxyKeyExpiresAt = 0.0
    let now: Date
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool

    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "NÃO DISPONÍVEL"
    }

    private var keyDuration: String {
        let remaining = max(0, proxyKeyExpiresAt - now.timeIntervalSince1970)
        let totalSeconds = Int(remaining)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("INFORMAÇÕES DA LICENÇA")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    DashboardInfoCard(rows: [
                        ("PRODUTO", "EXTERNAL", .white),
                        ("STATUS DA KEY", "VIP ATIVO", .green),
                        ("TEMPO DA KEY", keyDuration, .white),
                        ("EXPIRAÇÃO", proxyKeyExpiresAt > now.timeIntervalSince1970 ? keyDuration : "EXPIRADA", proxyKeyExpiresAt > now.timeIntervalSince1970 ? .green : .red),
                        ("CHAVE", proxyAccessKey.isEmpty ? "NÃO DISPONÍVEL" : proxyAccessKey, .secondary),
                        ("CONTATO", "SUPORTE ONLINE", .white),
                        ("ID DO DISPOSITIVO", deviceID, .secondary)
                    ])

                    Text("DISPOSITIVO & COMPATIBILIDADE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)

                    DashboardInfoCard(rows: [
                        ("MODELO", AppInfo.displayMachineName, .white),
                        ("VERSÃO IOS", "\(AppInfo.osVersion) (\(AppInfo.osBuild))", .white),
                        ("ROOT / PMAP", appState.isSupported ? "COMPATÍVEL (SIM)" : "INCOMPATÍVEL", appState.isSupported ? .green : .red)
                    ])

                    Text("SEGURANÇA & ANTICRACK")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)

                    DashboardInfoCard(rows: [
                        ("ANTI-DEBUGGING", "NÃO VERIFICADA", .secondary),
                        ("CRIPTOGRAFIA KEYCHAIN", "ATIVA", .green)
                    ])

                    Text("A key é armazenada no Keychain; a proteção anti-debugging não é declarada como ativa sem uma verificação nativa correspondente.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct KeyValidationView: View {
    var body: some View {
        ZStack {
            AppBackgroundView().ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().controlSize(.large).tint(AppTheme.accent)
                Text("VALIDANDO CHAVE SALVA").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1.1).foregroundStyle(.white.opacity(0.78))
                Text("Verificando sua licença com segurança…").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.glassStroke, lineWidth: 1))
        }
    }
}

private struct SecurityBlockedView: View {
    var body: some View {
        ZStack {
            AppBackgroundView().ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                Text("ACESSO BLOQUEADO")
                    .font(.title3.weight(.bold))
                    .tracking(1.2)
                Text("O ambiente do aplicativo não passou pelas verificações de segurança. Feche o app e abra-o novamente em um ambiente autorizado.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.glassStroke, lineWidth: 1))
            .padding(24)
        }
    }
}

private struct DashboardInfoCard: View {
    let rows: [(String, String, Color)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(row.1)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(row.2)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .padding(.vertical, 13)
                if index < rows.count - 1 {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}
