import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum PatchContentKind: String, CaseIterable, Identifiable {
    case patch
    case skin
    var id: String { rawValue }
    var title: String { self == .skin ? "Skin" : "Patches" }
}

private enum SkinCharacter: String, CaseIterable, Identifiable {
    case dimitri
    case alok
    var id: String { rawValue }
    static let verificationLabels = "Dimitri|Alok"
    var title: String { rawValue == "dimitri" ? "Dimitri" : "Alok" }
    var icon: String { rawValue == "dimitri" ? "shield.lefthalf.filled" : "music.note" }
}

private enum PatchPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
    static let copiesSelectedDocument = true
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @StateObject private var store = PatchProjectStore()
    @State private var showCreate = false
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var hasStartedInitialSync = false
    @AppStorage("proxy_appearance_mode") private var appearanceMode = "dark"
    @AppStorage(AppTheme.accentColorStorageKey) private var accentColorHex = AppTheme.defaultAccentHex
    @State private var selectedTab: GamePatchVersion
    @State private var selectedKind: PatchContentKind = .patch
    @State private var selectedCharacter: SkinCharacter = .dimitri
    let gameFilter: GamePatchVersion?

    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard let project = item.project else { return false }
            return project.name.localizedCaseInsensitiveContains(query)
                || project.allBundleIdentifiers.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
                || project.directories.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                }
                || project.rules.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                        || $0.replacementFilename.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var selectedItems: [PatchLibraryItem] {
        filteredItems.filter { item in
            guard category(for: item) == selectedTab, (item.remoteKind ?? "patch") == selectedKind.rawValue else { return false }
            return selectedKind == .patch || item.remoteCharacter == selectedCharacter.rawValue
        }
    }

    private func category(for item: PatchLibraryItem) -> GamePatchVersion {
        if item.remoteGame == "Free Fire MAX" || item.project?.allBundleIdentifiers.contains("com.dts.freefiremax") == true {
            return .max
        }
        return .normal
    }

    init(gameFilter: GamePatchVersion? = nil) {
        self.gameFilter = gameFilter
        _selectedTab = State(initialValue: gameFilter ?? .normal)
#if targetEnvironment(simulator)
        _showCreate = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("--simulate-patch-editor")
        )
#endif
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryTabs
                kindTabs
                if selectedKind == .skin { characterTabs }
                accentColorRow
                AppSearchField(
                    text: $searchText,
                    prompt: language.text("patch.search"),
                    clearLabel: language.text("common.clear")
                )
                Divider()
                List {
                    if store.items.isEmpty && !store.isBusy {
                        emptyState
                            .listRowSeparator(.hidden)
                    } else if selectedItems.isEmpty && !store.isBusy {
                        Group {
                            if filteredItems.isEmpty {
                                searchEmptyState
                            } else {
                                categoryEmptyState
                            }
                        }
                        .listRowSeparator(.hidden)
                    } else {
                        Section {
                            ForEach(selectedItems) { item in
                                itemRow(item)
                                    .padding(.vertical, 6)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                            .onDelete { offsets in
                                offsets.map { selectedItems[$0] }.forEach(store.delete)
                            }
                        } header: {
                            sectionHeader(selectedKind == .skin ? "\(selectedTab.title) · \(selectedCharacter.title)" : selectedTab.title)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .background(Color.clear)
            }
            .navigationTitle("Patches")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("remote-theme-patches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.synchronizeRemote()
                    } label: {
                        Image(systemName: store.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.down.circle")
                    }
                    .accessibilityLabel("Atualizar catálogo remoto")
                    .disabled(store.isSyncing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appearanceMode = appearanceMode == "dark" ? "light" : "dark"
                    } label: {
                        Image(systemName: appearanceMode == "dark" ? "sun.max.fill" : "moon.fill")
                    }
                    .accessibilityLabel(appearanceMode == "dark" ? "Ativar modo claro" : "Ativar modo escuro")
                }
            }
            .sheet(isPresented: $showImporter) {
                FileDocumentPicker(
                    allowedContentTypes: PatchPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: PatchPackagePickerPolicy.copiesSelectedDocument,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showImporter = false
                        if case .success(let urls) = result, let url = urls.first {
                            store.importPackage(at: url)
                        }
                    },
                    onCancel: {
                        showImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCreate) {
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false
                ) { project, password in
                    store.create(project: project, password: password)
                }
            }
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
            .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { _ in
                PatchUnlockView(store: store)
            }
            .alert(item: $store.alert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text(language.text("common.ok")))
                )
            }
            .onAppear {
                consumeExternalImport()
                guard !hasStartedInitialSync else { return }
                hasStartedInitialSync = true
                store.synchronizeRemote(showsCompletion: false)
            }
            .onChange(of: draftCoordinator.importRequest?.id) { _ in
                consumeExternalImport()
            }
        }
    }

    private var accentColorRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cor do app")
                    .font(.subheadline.weight(.semibold))
                Text("Nomes dos patches e destaques")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: accentColorHex))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1))
                Text("Sincronizada do painel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Cor remota atual: \(accentColorHex)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GamePatchVersion.allCases) { tab in
                    categoryTabButton(tab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.black.opacity(0.08))
    }

    private var kindTabs: some View {
        HStack(spacing: 10) {
            ForEach(PatchContentKind.allCases) { kind in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selectedKind = kind; if kind == .skin { selectedCharacter = .dimitri } }
                } label: {
                    Label(kind.title, systemImage: kind == .skin ? "sparkles" : "shippingbox")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedKind == kind ? AppTheme.accent : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedKind == kind ? AppTheme.accent.opacity(0.16) : Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedKind == kind ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var characterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SkinCharacter.allCases) { character in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { selectedCharacter = character }
                    } label: {
                        Label(character.title, systemImage: character.icon)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedCharacter == character ? AppTheme.accent : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCharacter == character ? AppTheme.accent.opacity(0.16) : Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedCharacter == character ? .isSelected : [])
                    .accessibilityLabel("Skin \(character.title)")
                    .accessibilityIdentifier("skin-character-\(character.rawValue)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .accessibilityIdentifier("skin-character-sections")
        .accessibilityValue(SkinCharacter.verificationLabels)
    }

    private func categoryTabButton(_ tab: GamePatchVersion) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { selectedTab = tab }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(isSelected ? tab.accent : Color.white.opacity(0.26)).frame(width: 7, height: 7)
                Text(tab.title).font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(isSelected ? tab.accent.opacity(0.88) : Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(isSelected ? tab.accent : Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.accent)
            .textCase(nil)
            .padding(.top, 8)
    }

    private func consumeExternalImport() {
        guard let request = draftCoordinator.importRequest else { return }
        draftCoordinator.clearImport()
        store.importPackage(from: request.source)
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem) -> some View {
        Button {
            guard !item.isLocked else {
                store.requestUnlock(for: item)
                return
            }
            store.setEnabled(!store.isActive(item), for: item)
        } label: {
            PatchProjectRow(
                item: item,
                language: language,
                isActive: store.isActive(item),
                isApplying: store.isApplyingPatchIDs.contains(item.id)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isApplyingPatchIDs.contains(item.id))
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityLabel(
            item.isLocked
                ? language.text("patch.tap_to_unlock")
                : (store.isActive(item) ? "Desmarcar e restaurar \(item.remoteKind == "skin" ? "skin" : "patch")" : "Selecionar e aplicar \(item.remoteKind == "skin" ? "skin" : "patch")")
        )
        .accessibilityHint(
            item.isLocked
                ? "Toque para desbloquear este item"
                : (store.isActive(item) ? "Toque para desmarcar e restaurar o original" : "Toque para selecionar e aplicar")
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text(language.text("patch.empty_title"))
                .font(.headline)
            Text(language.text("patch.empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(language.text("patch.new")) { showCreate = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var categoryEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedTab == .max ? "sparkles" : "shippingbox")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(selectedTab.accent)
            Text(selectedKind == .skin ? "Nenhuma skin de \(selectedCharacter.title) nesta aba" : "Nenhum patch nesta aba")
                .font(.headline)
            Text("Os patches publicados para esta categoria aparecerão aqui.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("patch.search_empty"))
                .font(.headline)
            Text(language.text("patch.search_empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct HSVIPSPulse: ViewModifier {
    @State private var isPulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

private struct PatchProjectRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage
    let isActive: Bool
    let isApplying: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let iconURL = item.remoteIconURL, let image = UIImage(contentsOfFile: iconURL.path) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                AppRowIcon(systemName: item.remoteKind == "skin" ? "sparkles" : (item.isLocked ? "lock.doc.fill" : "shippingbox.fill"))
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project?.name ?? language.text("patch.locked_project"))
                     .font(.system(size: 15, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.accent)
                    .shadow(color: AppTheme.accent.opacity(0.55), radius: 8)
                Text(item.isLocked
                     ? language.text("patch.tap_to_unlock")
                     : language.text(
                        item.summary.schemaVersion >= 2 ? "patch.workspace_items_count" : "patch.rules_count",
                        Int64((item.project?.rules.count ?? 0) + (item.project?.directories.count ?? 0))
                     ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isApplying {
                ProgressView()
                    .tint(AppTheme.accent)
                    .accessibilityLabel("Aplicando alteração")
            } else if !item.isLocked {
                PatchSelectionVisual(isSelected: isActive)
            }
            if item.summary.isPasswordProtected {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(language.text("patch.password_protected"))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isActive ? AppTheme.accent.opacity(0.70) : AppTheme.glassStroke,
                    lineWidth: isActive ? 1.5 : 1
                )
        }
        .shadow(
            color: isActive ? AppTheme.accent.opacity(0.24) : .black.opacity(0.18),
            radius: isActive ? 16 : 14,
            y: 7
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: isActive)
        .animation(.easeInOut(duration: 0.22), value: item.isLocked)
        .modifier(HSVIPSPulse())
    }
}

private struct PatchSelectionVisual: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary.opacity(0.82))
            .accessibilityLabel(isSelected ? "Selecionado; toque para restaurar o original" : "Não selecionado; toque para aplicar")
    }
}

private struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                } footer: {
                    Text(language.text("patch.password_once_message"))
                }
            }
            .navigationTitle(language.text("patch.unlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("patch.unlock"), action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    @State private var showEditor = false
    @State private var editingRule: PatchRule?
    @State private var showApplyConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var isWorking = false
    @State private var actionAlert: PatchStoreAlert?

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: projectID)
    }

    private var isWorkspaceProject: Bool {
        (item?.summary.schemaVersion ?? 1) >= 2
    }

    var body: some View {
        List {
            if let item, let project = item.project {
                if isWorkspaceProject {
                    Section {
                        ForEach(project.allBundleIdentifiers, id: \.self) { bundleID in
                            Label {
                                Text(bundleID)
                                    .font(.subheadline.monospaced())
                            } icon: {
                                Image(systemName: "app.dashed")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        LabeledContent(language.text("patch.files")) {
                            Text("\(project.rules.count)")
                        }
                        LabeledContent(language.text("patch.folders")) {
                            Text("\(project.directories.count)")
                        }
                    } header: {
                        Text(language.text("patch.workspace"))
                    }
                } else {
                    Section {
                        ForEach(project.rules) { rule in
                            Button {
                                editingRule = rule
                            } label: {
                                HStack(spacing: 10) {
                                    ruleSummary(rule)
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(language.text("patch.edit_rule_hint"))
                        }
                    } header: {
                        Text(language.text("patch.rules"))
                    } footer: {
                        Text(language.text("patch.legacy_footer"))
                    }
                }

                Section(language.text("patch.password")) {
                    HStack(spacing: 12) {
                        Image(systemName: item.summary.isPasswordProtected ? "lock.fill" : "lock.open")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Text(language.text(item.summary.isPasswordProtected
                            ? "patch.password_locked"
                            : "patch.no_password"))
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        showApplyConfirmation = true
                    } label: {
                        actionLabel("patch.apply", systemImage: "checkmark.shield.fill")
                    }
                    .disabled(isWorking)

                    if receipt != nil {
                        Button(role: .destructive) {
                            showRestoreConfirmation = true
                        } label: {
                            actionLabel("patch.restore", systemImage: "arrow.uturn.backward.circle")
                        }
                        .disabled(isWorking)
                    }
                } footer: {
                    Text(language.text("patch.apply_footer"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item?.project?.name ?? language.text("patch.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isWorking {
                    ProgressView()
                } else if !isWorkspaceProject {
                    Button(language.text("patch.edit")) { showEditor = true }
                        .disabled(item?.project == nil)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let item, let project = item.project {
                PatchProjectEditorView(
                    existingProject: project,
                    passwordIsProtected: item.summary.isPasswordProtected
                ) { updatedProject, _ in
                    store.update(project: updatedProject)
                }
            }
        }
        .sheet(item: $editingRule) { rule in
            PatchRuleEditorView(rule: rule) { updatedRule in
                updateRule(updatedRule)
            }
        }
        .confirmationDialog(
            language.text("patch.apply_confirm_title"),
            isPresented: $showApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("patch.apply")) { apply() }
            Button(language.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(language.text("patch.apply_confirm_message"))
        }
        .confirmationDialog(
            language.text("patch.restore_confirm_title"),
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text("patch.restore"), role: .destructive) { restore() }
            Button(language.text("common.cancel"), role: .cancel) {}
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
    }

    private func actionLabel(_ key: String, systemImage: String) -> some View {
        Label(language.text(key), systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ruleSummary(_ rule: PatchRule) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(rule.bundleID)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(rule.relativePath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Label(rule.replacementFilename, systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.vertical, 3)
    }

    private func updateRule(_ updatedRule: PatchRule) {
        guard var project = item?.project,
              let index = project.rules.firstIndex(where: { $0.id == updatedRule.id }) else {
            return
        }
        project.rules[index] = updatedRule
        project.updatedAt = Date()
        do {
            try PatchPackageCodec.validate(project)
            store.update(project: project)
        } catch let error as PatchPackageError {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: error.localizationKey,
                messageArgument: error.localizationArgument
            )
        } catch {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: "patch.error.invalid_project"
            )
        }
    }

    private func apply() {
        guard let item, let baseProject = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply")
                }
            }
        }
    }

    private func restore() {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.restore")
                }
            }
        }
    }
}
