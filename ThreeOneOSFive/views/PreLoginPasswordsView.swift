import SwiftUI
import UIKit

struct PreLoginPasswordsView: View {
    let onContinue: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: PreLoginPasswordCategory?
    @State private var isShowingVoiceNotice = false
    @State private var isShowingAbout = false
    @State private var isCharging = false

    private var filteredCategories: [PreLoginPasswordCategory] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return PreLoginPasswordCategory.allCases }

        return PreLoginPasswordCategory.allCases.filter { category in
            category.title.localizedCaseInsensitiveContains(query) ||
            category.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.945, green: 0.945, blue: 0.965)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if filteredCategories.isEmpty {
                        noResultsView
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(filteredCategories) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    PreLoginCategoryCard(category: category)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 112)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                searchDock
            }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .sheet(item: $selectedCategory) { category in
            PreLoginCategoryDetailView(category: category, onContinue: continueIfCharging)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $isShowingAbout) {
            PreLoginAboutView(onContinue: continueIfCharging)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
        }
        .alert("Busca por voz", isPresented: $isShowingVoiceNotice) {
            Button("Fechar", role: .cancel) { }
        } message: {
            Text("O botão de áudio está disponível visualmente nesta tela. A busca continua funcionando pelo campo de texto.")
        }
        .onAppear(perform: startBatteryMonitoring)
        .onDisappear(perform: stopBatteryMonitoring)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            isCharging = chargerIsConnected
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tela inicial de Senhas")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Senhas")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(Color.black)
                .lineLimit(1)

            Spacer(minLength: 8)

            if isCharging {
                Menu {
                    Button("Entrar no sistema", action: continueIfCharging)
                    Button("Sobre esta tela") {
                        isShowingAbout = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.80))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Mais opções")
            } else {
                Image(systemName: "bolt.slash.circle")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(Color.gray.opacity(0.72))
                    .frame(width: 40, height: 40)
                    .accessibilityLabel("Conecte o carregador para liberar o login")
            }
        }
        .padding(.horizontal, 2)
    }

    private var searchDock: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.gray)
                    .accessibilityHidden(true)

                TextField("Buscar", text: $searchText)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.black)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.gray.opacity(0.78))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Limpar busca")
                }

                Button {
                    isShowingVoiceNotice = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.90))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Busca por áudio")
            }
            .padding(.horizontal, 13)
            .frame(height: 48)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)

            Button(action: continueIfCharging) {
                Image(systemName: isCharging ? "plus" : "bolt.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(isCharging ? Color.black.opacity(0.84) : Color.gray.opacity(0.72))
                    .frame(width: 48, height: 48)
                    .background(Color.white, in: Circle())
                    .overlay {
                        Circle().stroke(Color.black.opacity(0.07), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!isCharging)
            .opacity(isCharging ? 1 : 0.72)
            .accessibilityLabel(isCharging ? "Adicionar item e abrir login" : "Conecte o carregador para abrir o login")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var chargerIsConnected: Bool {
        switch UIDevice.current.batteryState {
        case .charging, .full:
            return true
        case .unplugged, .unknown:
            return false
        @unknown default:
            return false
        }
    }

    private func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        isCharging = chargerIsConnected
    }

    private func stopBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    private func continueIfCharging() {
        guard isCharging else { return }
        onContinue()
    }

    private var noResultsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.gray)

            Text("Nenhum resultado")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.78))

            Text("Tente buscar por outra categoria.")
                .font(.system(size: 14))
                .foregroundStyle(Color.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private enum PreLoginPasswordCategory: String, CaseIterable, Identifiable, Equatable {
    case all
    case passkeys
    case codes
    case wifi
    case security
    case deleted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .passkeys: return "Chaves-senha"
        case .codes: return "Códigos"
        case .wifi: return "Wi-Fi"
        case .security: return "Segurança"
        case .deleted: return "Apagadas"
        }
    }

    var subtitle: String {
        switch self {
        case .all: return "Senhas e contas salvas"
        case .passkeys: return "Acesso sem senha"
        case .codes: return "Códigos de verificação"
        case .wifi: return "Redes conhecidas"
        case .security: return "Recomendações de segurança"
        case .deleted: return "Itens removidos recentemente"
        }
    }

    var count: Int {
        switch self {
        case .all: return 10
        case .passkeys: return 0
        case .codes: return 0
        case .wifi: return 6
        case .security: return 0
        case .deleted: return 0
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "key.fill"
        case .passkeys: return "person.fill"
        case .codes: return "lock.fill"
        case .wifi: return "wifi"
        case .security: return "checkmark.shield.fill"
        case .deleted: return "trash.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: return Color.blue
        case .passkeys: return Color.green
        case .codes: return Color.orange
        case .wifi: return Color.cyan
        case .security: return Color.gray
        case .deleted: return Color.orange
        }
    }

    var examples: [String] {
        switch self {
        case .all: return ["Apple", "Free Fire", "Manus"]
        case .wifi: return ["TEREZA_5G", "Gramados Sorveteria"]
        case .passkeys, .codes, .security, .deleted: return []
        }
    }
}

private struct PreLoginCategoryCard: View {
    let category: PreLoginPasswordCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(category.tint.opacity(0.14))

                    Image(systemName: category.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(category.tint)
                }
                .frame(width: 42, height: 42)

                Spacer(minLength: 4)

                Text(String(category.count))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.gray)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(category.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PreLoginCategoryDetailView: View {
    let category: PreLoginPasswordCategory
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if category.examples.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(category.tint)

                        Text(category.title)
                            .font(.title2.weight(.bold))

                        Text("Nenhum item disponível nesta visualização.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("Abrir tela de login", action: onContinue)
                            .buttonStyle(.borderedProminent)
                    }
                    .multilineTextAlignment(.center)
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(category.examples, id: \.self) { example in
                        Label(example, systemImage: category == .wifi ? "wifi" : "person.crop.circle")
                    }
                    .listStyle(.insetGrouped)
                    .safeAreaInset(edge: .bottom) {
                        Button("Abrir tela de login", action: onContinue)
                            .buttonStyle(.borderedProminent)
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

private struct PreLoginAboutView: View {
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Color.blue)

                Text("Acesso protegido")
                    .font(.title2.weight(.bold))

                Text("Esta tela é uma apresentação visual. O acesso ao PROXY SYSTEM continua protegido pela validação da chave.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button("Entrar no sistema", action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .navigationTitle("Sobre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PreLoginPasswordsView { }
}
