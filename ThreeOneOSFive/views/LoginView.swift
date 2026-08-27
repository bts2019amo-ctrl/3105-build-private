import SwiftUI



private struct ProxyKeyValidation: Decodable {
  
    let valid: Bool
  
    let daysLeft: Int?
  
    let reason: String?
  
}



private struct ProxyTRPCData: Decodable {
  
    let json: ProxyKeyValidation
  
}



private struct ProxyTRPCResult: Decodable {
  
    let data: ProxyTRPCData
  
}



private struct ProxyTRPCResponse: Decodable {
  
    let result: ProxyTRPCResult
  
}



struct ProxyLoginView: View {
  
    @AppStorage("proxy_access_key") private var storedKey = ""
    @AppStorage("proxy_days_left") private var proxyDaysLeft = 0
    @AppStorage("proxy_key_expires_at") private var proxyKeyExpiresAt = 0.0
  
    @State private var key = ""
  
    @State private var isLoading = false
  
    @State private var errorMessage: String?
  
    @State private var showSuccess = false
  

  
    var body: some View {
      
        ZStack {
          
            AppBackgroundView().ignoresSafeArea()
          
            ScrollView {
              
                VStack(spacing: 22) {
                  
                    Spacer(minLength: 54)
                  
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 104, height: 104)
                            .overlay(Circle().stroke(AppTheme.accent.opacity(0.45), lineWidth: 1))
                            .shadow(color: AppTheme.accent.opacity(0.24), radius: 22)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .shadow(color: AppTheme.accent.opacity(0.55), radius: 18)
                    }
                    Text("PROXY SYSTEM")
                        .font(.title3.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.accent)
                    Text("ACESSO SEGURO AO SISTEMA")
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 10) {

                      
                        Text("CHAVE DE ACESSO")
                      
                            .font(.caption.weight(.bold))
                      
                            .foregroundStyle(.secondary)
                      
                        SecureField("Digite sua chave", text: $key)
                      
                            .textInputAutocapitalization(.never)
                      
                            .autocorrectionDisabled()
                      
                            .padding(16)
                      
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                      
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.accent.opacity(0.45), lineWidth: 1))
                      
                    }
                  
                    if let errorMessage {
                      
                        Text(errorMessage)
                      
                            .font(.footnote)
                      
                            .foregroundStyle(.red)
                      
                            .multilineTextAlignment(.center)
                      
                    }
                  
                    Button {
                      
                        Task { await validateKey() }
                      
                    } label: {
                      
                        HStack {
                          
                            if isLoading { ProgressView().tint(.white) }
                          
                            Text(isLoading ? "VALIDANDO..." : "ENTRAR")
                          
                                .font(.headline.weight(.bold))
                          
                        }
                      
                        .frame(maxWidth: .infinity)
                      
                        .padding(.vertical, 16)
                      
                    }
                  
                    .foregroundStyle(.white)
                  
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16))
                  
                    .disabled(isLoading || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                  
                    Text("Sua chave é validada com segurança pelo servidor.")
                  
                        .font(.caption)
                  
                        .foregroundStyle(.secondary)
                  
                    Spacer(minLength: 54)
                  
                }
              
                                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(AppTheme.glassStroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
                .padding(.horizontal, 18)
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
          
            Button("Continuar", role: .cancel) {}
          
        } message: {
          
            Text("Sua chave foi validada com sucesso.")
          
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
          
            let payload: [String: Any] = ["0": ["json": ["key": trimmed]]]
          
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
          
            let json = String(data: jsonData, encoding: .utf8) ?? "{}"
          
            let encoded = json.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
          
            guard let url = URL(string: "https://proxysystem.org/api/trpc/iOS.validateKey?batch=1&input=\(encoded)") else { throw URLError(.badURL) }
          
            var request = URLRequest(url: url)
          
            request.httpMethod = "GET"
          
            request.timeoutInterval = 10
          
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          
            var (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 404 {
              guard let fallbackURL = URL(string: "https://proxysystem.org/api/trpc/android.validateKey?batch=1&input=\(encoded)") else { throw URLError(.badURL) }
              request.url = fallbackURL
              (data, response) = try await URLSession.shared.data(for: request)
            }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
          
            let result = try JSONDecoder().decode([ProxyTRPCResponse].self, from: data).first?.result.data.json
          
            guard let result else { throw URLError(.cannotParseResponse) }
          
            if result.valid {
              
                storedKey = trimmed
                proxyDaysLeft = result.daysLeft ?? 0
                proxyKeyExpiresAt = Date().addingTimeInterval(TimeInterval(max(0, result.daysLeft ?? 0)) * 86_400).timeIntervalSince1970
                showSuccess = true

            } else {
              
                errorMessage = result.reason ?? "Chave inválida ou expirada."
              
            }
          
        } catch {
          
            errorMessage = "Não foi possível conectar ao servidor." 
          
        }
      
    }
  
}



















































































































