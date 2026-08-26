import SwiftUI

struct LoginView: View {
    let onAuthenticated: () -> Void
    @AppStorage("proxy_access_key") private var savedKey = ""
    @State private var accessKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            VideoBackgroundView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            LinearGradient(
                colors: [Color.black, Color(red: 0.12, green: 0.01, blue: 0.02), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.38)
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 56)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(.red)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("FFH4X SYSTEM")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                        Text("Digite sua chave de acesso para continuar")
                            .font(.subheadline)
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 14) {
                        SecureField("XXXX-XXXX-XXXX-XXXX", text: $accessKey)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit(validate)
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.09))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.65), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button(action: validate) {
                            HStack(spacing: 10) {
                                if isLoading { ProgressView().tint(.white) }
                                Text(isLoading ? "VALIDANDO..." : "VALIDAR CHAVE")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(isLoading || accessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxWidth: 390)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 390)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if accessKey.isEmpty { accessKey = savedKey }
            if !savedKey.isEmpty { validate() }
        }
        .alert("Chave validada", isPresented: $showSuccess) {
            Button("Continuar", action: onAuthenticated)
        } message: {
            Text("Sua chave foi validada com sucesso.")
        }
    }

    private func validate() {
        let key = accessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil

        var components = URLComponents(string: "https://proxysystem.org/api/trpc/android.validateKey")
        let payload: [String: Any] = ["0": ["json": ["key": key]]]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            isLoading = false
            errorMessage = "Não foi possível preparar a solicitação."
            return
        }
        components?.queryItems = [
            URLQueryItem(name: "batch", value: "1"),
            URLQueryItem(name: "input", value: json)
        ]
        guard let url = components?.url else {
            isLoading = false
            errorMessage = "URL da API inválida."
            return
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                guard error == nil, let data,
                      let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    errorMessage = "Não foi possível conectar ao servidor."
                    return
                }
                do {
                    let root = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                    let json = root?.first?["result"] as? [String: Any]
                    let dataObject = json?["data"] as? [String: Any]
                    let result = dataObject?["json"] as? [String: Any]
                    let valid = result?["valid"] as? Bool ?? false
                    if valid {
                        savedKey = key
                        showSuccess = true
                    } else {
                        errorMessage = (result?["reason"] as? String) ?? "Chave inválida ou expirada."
                    }
                } catch {
                    errorMessage = "Resposta inválida da API."
                }
            }
        }.resume()
    }
}
