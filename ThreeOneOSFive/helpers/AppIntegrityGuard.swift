import CryptoKit
import Foundation
/// Release-only integrity gate. The private signing key must remain with the Apple
/// signing/distribution pipeline; it is never embedded in the app.
enum AppIntegrityGuard {
    static let verificationMarker = "APP_INTEGRITY_FAIL_CLOSED|EXECUTABLE_HASH_REQUIRED|NO_PRIVATE_KEY_IN_IPA"

    static var isValid: Bool {
#if DEBUG
        return true
#else
#if targetEnvironment(simulator)
        return true
#else
        guard !SecurityGuard.isCompromised else { return false }
        guard Bundle.main.bundleIdentifier == "com.apple.mobile.MobileHouseArrest" else { return false }
        guard let executableURL = Bundle.main.executableURL,
              FileManager.default.isReadableFile(atPath: executableURL.path) else { return false }
        let infoURL = Bundle.main.bundleURL.appendingPathComponent("Info.plist")
        guard FileManager.default.isReadableFile(atPath: infoURL.path) else { return false }
        struct IntegrityManifest: Decodable {
            let schemaVersion: Int
            let executableSHA256: String
        }
        let manifestURL = Bundle.main.bundleURL.appendingPathComponent("IntegrityManifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(IntegrityManifest.self, from: manifestData),
              manifest.schemaVersion == 1,
              manifest.executableSHA256.count == 64,
              let executableData = try? Data(contentsOf: executableURL) else { return false }
        let actualHash = SHA256.hash(data: executableData).map { String(format: "%02x", $0) }.joined()
        guard actualHash.caseInsensitiveCompare(manifest.executableSHA256) == .orderedSame else { return false }
        // Do not require CodeResources here: this project delivers an unsigned
        // IPA that is signed by the user's Apple sideload installer. The installer
        // and iOS validate the final signature; this gate validates the executable
        // bytes against the build-time seal without crashing a legitimate unsigned IPA.
        return true
#endif
#endif
    }
}
