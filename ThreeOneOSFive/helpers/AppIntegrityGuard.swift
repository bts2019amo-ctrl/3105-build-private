import Foundation
import Security

/// Release-only integrity gate. The private signing key must remain with the Apple
/// signing/distribution pipeline; it is never embedded in the app.
enum AppIntegrityGuard {
    static let verificationMarker = "APP_INTEGRITY_FAIL_CLOSED|BUNDLE_SIGNATURE_REQUIRED|NO_PRIVATE_KEY_IN_IPA"

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
        guard let infoURL = Bundle.main.url(forResource: "Info", withExtension: "plist"),
              FileManager.default.isReadableFile(atPath: infoURL.path) else { return false }
        // Require the platform to validate the signed code before the UI starts.
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        guard SecCodeCheckValidity(code, [], nil) == errSecSuccess else { return false }
        guard let signingInfo = SecCodeCopySigningInformation(code, SecCSFlags(), nil) as? [String: Any],
              let identifier = signingInfo[kSecCodeInfoIdentifier as String] as? String,
              identifier == Bundle.main.bundleIdentifier else { return false }
        // A distributable iOS app must carry the CodeResources seal after signing.
        let codeResources = Bundle.main.bundleURL
            .appendingPathComponent("_CodeSignature", isDirectory: true)
            .appendingPathComponent("CodeResources")
        guard FileManager.default.isReadableFile(atPath: codeResources.path) else { return false }
        return true
#endif
#endif
    }
}
