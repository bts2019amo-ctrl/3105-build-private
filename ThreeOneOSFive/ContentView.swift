import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init() {
#if targetEnvironment(simulator)
        let initialTab = ProcessInfo.processInfo.arguments.contains("--simulate-patch-tab") ? AppSection.patches.rawValue : 0
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular { regularLayout } else { compactLayout }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { id in if id != nil { tabNavigation.select(AppSection.patches.rawValue) } }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { id in if id != nil { tabNavigation.select(AppSection.patches.rawValue) } }
        .onAppear { tabNavigation.reconcileSelection(with: navigationFeatureVisibility) }
    }

    private var visibleNavigationSections: [AppSection] { [.home, .patches] }
    private var navigationFeatureVisibility: FeatureVisibility { FeatureVisibility(cleanerEnabled: false, wallpapersEnabled: false, wallpapersSupported: false) }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(visibleNavigationSections) { section in
                sectionContent(section)
                    .tabItem { CompactTabLabel(title: language.text(section.titleKey), systemImage: section.systemImage) }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(visibleNavigationSections) { section in
                    Button { tabNavigation.select(section.rawValue) } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection).id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home: DashboardView()
        case .files: AppDataBrowserView(tabSession: filesTabSession)
        case .patches: PatchProjectsView()
        case .cleaner: CleanerView()
        case .wallpapers: WallpaperLabView()
        }
    }

    private var tabSelection: Binding<Int> { Binding(get: { tabNavigation.selectedTab }, set: { tabNavigation.select($0) }) }
    private var filesTabSession: Binding<FilesTabSession> { Binding(get: { tabNavigation.filesTabs }, set: { tabNavigation.setFilesTabs($0) }) }
    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab), visibleNavigationSections.contains(section) else { return .home }
        return section
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String
    var body: some View { Label(title, systemImage: systemImage) }
}

private extension AppSection {
    var titleKey: String {
        switch self { case .home: return "tab.home"; case .files: return "tab.files"; case .patches: return "tab.patches"; case .cleaner: return "tab.cleaner"; case .wallpapers: return "tab.wallpapers" }
    }
    var systemImage: String {
        switch self { case .home: return "house.fill"; case .files: return "folder.fill"; case .patches: return "shippingbox.fill"; case .cleaner: return "sparkles"; case .wallpapers: return "photo.on.rectangle.angled" }
    }
}

private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            List { deviceSection }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) { Button { showLogs = true } label: { Image(systemName: "apple.terminal") } }
                    ToolbarItem(placement: .navigationBarTrailing) { Button { showSettings = true } label: { Image(systemName: "gearshape") } }
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .sheet(isPresented: $showLogs) { LogView() }
        }
    }

    private var deviceSection: some View {
        Section {
            LabeledContent(language.text("dashboard.hardware_model")) { Text(AppInfo.displayMachineName).font(.body.monospaced()) }
            LabeledContent(language.text("settings.ios_version")) { Text("\(AppInfo.osVersion) (\(AppInfo.osBuild))").font(.body.monospaced()) }
            HStack {
                Text(language.text("settings.compatibility")); Spacer()
                Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                    .foregroundStyle(appState.isSupported ? Color.green : Color.red)
            }
        } header: { Text(language.text("common.device")) } footer: { Text(language.text("settings.supported_range_summary")) }
    }
}
