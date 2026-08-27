import Foundation

struct KeyRevalidationResult: Decodable {
    let valid: Bool
    let daysLeft: Int?
    let reason: String?
}

private struct KeyTRPCData: Decodable { let json: KeyRevalidationResult }
private struct KeyTRPCResult: Decodable { let data: KeyTRPCData }
private struct KeyTRPCResponse: Decodable { let result: KeyTRPCResult }

enum KeyRevalidationService {
    enum ValidationError: Error {
        case invalidURL
        case server
        case response
    }

    static func validate(_ key: String) async throws -> KeyRevalidationResult {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.response }

        let payload: [String: Any] = ["0": ["json": ["key": trimmed]]]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let json = String(data: jsonData, encoding: .utf8) ?? "{}"
        let encoded = json.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let validationURL = URL(string: "https://proxysystem.org/api/trpc/android.validateKey?batch=1&input=\(encoded)") else {
            throw ValidationError.invalidURL
        }

        var request = URLRequest(url: validationURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ValidationError.server }
        guard let result = try JSONDecoder().decode([KeyTRPCResponse].self, from: data).first?.result.data.json else {
            throw ValidationError.response
        }
        return result
    }
}
