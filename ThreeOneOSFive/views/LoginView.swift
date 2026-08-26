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
                  
                    Image(systemName: "lock.shield.fill")
                  
                        .font(.system(size: 58, weight: .bold))
                  
                        .foregroundStyle(AppTheme.accent)
                  
                        .shadow(color: AppTheme.accent.opacity(0.55), radius: 18)
                  
                    Text("PROXY SYSTEM")
                  
                        .font(.headline)
                  
                        .tracking(1.5)
                  
                        .foregroundStyle(AppTheme.accent)
                  
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
              
            }
          
        }
      
        .preferredColorScheme(.dark)
      
        .onAppear { key = storedKey }
      
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
              
                showSuccess = true
              
            } else {
              
                errorMessage = result.reason ?? "Chave inválida ou expirada."
              
            }
          
        } catch {
          
            errorMessage = "Não foi possível conectar ao servidor." 
          
        }
      
    }
  
}



















































































































