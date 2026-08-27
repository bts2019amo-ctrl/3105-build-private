import SwiftUI

struct ProxyLoginView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("proxy_access_key") private var storedKey = ""
    @AppStorage("proxy_days_left") private var proxyDaysLeft = 0
    @AppStorage("proxy_key_expires_at") private var proxyKeyExpiresAt = 0.0

    @State private var key = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @FocusState private var keyFieldFocused: Bool

    private var canSubmit: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 34)

                    loginCard
                        .padding(.top, 28)

                    footer
                        .padding(.top, 18)
                        .padding(.bottom, 34)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if proxyKeyExpiresAt > 0 && proxyKeyExpiresAt <= Date().timeIntervalSince1970 {
                storedKey = ""
                proxyDaysLeft = 0
                proxyKeyExpiresAt = 0
                key = ""
            } else {
                key = storedKey
            }
        }
        .alert("Acesso liberado", isPresented: $showSuccess) {
            Button("Continuar", role: .cancel) { }
        } message: {
            Text("Sua chave foi validada com sucesso.")
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(AppTheme.accent.opacity(0.12)))
                    .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: 1))
                    .frame(width: 94, height: 94)
                    .shadow(color: AppTheme.accent.opacity(0.30), radius: 28, y: 10)

                Circle()
                    .stroke(AppTheme.accent.opacity(0.36), lineWidth: 1)
                    .frame(width: 76, height: 76)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 7) {
                Text("PROXY SYSTEM")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.white)

                Text("CONTROLE • PRIVACIDADE • PERFORMANCE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.35)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bem-vindo de volta")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Insira sua chave para liberar o sistema.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.60))
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("CHAVE DE ACESSO")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.64))

                HStack(spacing: 12) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 22)

                    SecureField("Digite sua chave", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($keyFieldFocused)
                        .onSubmit {
                            if canSubmit { Task { await validateKey() } }
                        }

                    if !key.isEmpty {
                        Button { key = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Limpar chave")
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 58)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(keyFieldFocused ? AppTheme.accent.opacity(0.85) : Color.white.opacity(0.22), lineWidth: keyFieldFocused ? 1.5 : 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.red.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                keyFieldFocused = false
                Task { await validateKey() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 19, weight: .bold))
                    }
                    Text(isLoading ? "VALIDANDO CHAVE" : "ENTRAR NO SISTEMA")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(0.8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [AppTheme.accent.opacity(canSubmit ? 1 : 0.48), Color.blue.opacity(canSubmit ? 0.72 : 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.24), lineWidth: 1))
            .shadow(color: AppTheme.accent.opacity(canSubmit ? 0.30 : 0.08), radius: 20, y: 10)
            .disabled(!canSubmit)
            .animation(.easeOut(duration: 0.18), value: canSubmit)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Validação segura pelo servidor")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.36), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 30, y: 18)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(Color.green).frame(width: 7, height: 7)
            Text("SISTEMA ONLINE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.52))
        }
    }

    @MainActor
    private func validateKey() async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await KeyRevalidationService.validate(trimmed)

            if result.valid {
                storedKey = trimmed
                proxyDaysLeft = result.daysLeft ?? 0
                proxyKeyExpiresAt = Date().addingTimeInterval(TimeInterval(max(0, result.daysLeft ?? 0)) * 86_400).timeIntervalSince1970
                appState.markKeySessionValid()
                showSuccess = true
            } else {
                errorMessage = result.reason ?? "Chave inválida ou expirada."
            }
        } catch {
            errorMessage = "Não foi possível conectar ao servidor."
        }
    }
}
