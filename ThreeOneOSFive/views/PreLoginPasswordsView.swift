import SwiftUI
import UIKit

struct PreLoginPasswordsView: View {
    let onContinue: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: PreLoginPasswordCategory?
    @State privafte var isShowingVoiceNotice = false
    @State private var isShowingGeneratedPasswords = false
    @State private var isShowingExportNotice = false
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
                VStack(alignment: .leading, spacing: 8) {
                    header

                    if filteredCategories.isEmpty {
                        noResultsView
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
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
                .padding(.horizontal, 10)
                .padding(.top, 2)
                .padding(.bottom, 96)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                searchDock
            }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .sheet(item: $selectedCategory) { category in
            PreLoginCategoryDetailView(category: category)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
        }
        .alert("Busca por voz", isPresented: $isShowingVoiceNotice) {
            Button("Fechar", role: .cancel) { }
        } message: {
            Text("O botão de áudio está disponível visualmente nesta tela. A busca continua funcionando pelo campo de texto.")
        }
        .alert("Senhas Geradas", isPresented: $isShowingGeneratedPasswords) {
            Button("Fechar", role: .cancel) { }
        } message: {
            Text("Nenhuma senha gerada disponível nesta visualização.")
        }
        .alert("Exportação de dados", isPresented: $isShowingExportNotice) {
            Button("Fechar", role: .cancel) { }
        } message: {
            Text("A exportação permanece desativada para manter as informações e os patches privados no app.")
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
            Spacer(minLength: 0)

            Menu {
                Button {
                    isShowingGeneratedPasswords = true
                } label: {
                    Label("Senhas Geradas", systemImage: "keyboard")
                }
                Button {
                    isShowingExportNotice = true
                } label: {
                    Label("Exportar Dados para Outro App", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(width: 40, height: 40)
                    .background(Color.white, in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("Mais opções")
        }
        .padding(.horizontal, 0)
    }

    private var searchDock: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.92))
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.white)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Busca por áudio")
            }
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(Color.black, in: Circle())
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)

            Button(action: continueIfCharging) {
                    Image(systemName: "plus")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black, in: Circle())
                    .overlay {
                        Circle().stroke(Color.black.opacity(0.07), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!isCharging)
            .opacity(1)
            .accessibilityLabel(isCharging ? "Adicionar item e abrir login" : "Adicionar item e abrir login quando o carregador estiver conectado")
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .background(Color.clear)
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
        case .all: return Color(red: 0.15, green: 0.43, blue: 0.88)
        case .passkeys: return Color(red: 0.30, green: 0.72, blue: 0.30)
        case .codes: return Color(red: 0.95, green: 0.75, blue: 0.12)
        case .wifi: return Color(red: 0.31, green: 0.64, blue: 0.80)
        case .security: return Color(red: 0.53, green: 0.54, blue: 0.57)
        case .deleted: return Color(red: 0.91, green: 0.52, blue: 0.13)
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
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                ZStack {
                    Circle()
                        .fill(category.tint)

                    Image(systemName: category.systemImage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 36, height: 36)

                Spacer(minLength: 4)

                Text(String(category.count))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.gray)
            }

            Text(category.title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.black.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PreLoginCategoryDetailView: View {
    let category: PreLoginPasswordCategory

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

                    }
                    .multilineTextAlignment(.center)
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(category.examples, id: \.self) { example in
                        Label(example, systemImage: category == .wifi ? "wifi" : "person.crop.circle")
                    }
                    .listStyle(.insetGrouped)
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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Color.blue)

                Text("Acesso protegido")
                    .font(.title2.weight(.bold))

                Text("Esta tela é uma apresentação visual. O acesso ao PROXY SYSTEM continua protegido pela validação da chave.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                
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
