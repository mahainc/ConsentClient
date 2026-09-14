import AnalyticsClient
import ConsentClient
import Dependencies
import UIKit
@preconcurrency import UserMessagingPlatform

/// Google's half of consent: the information update, and the form when one is required.
enum UMPFlow {
    static func requestConsent(_ config: ConsentClient.Config) async throws -> ConsentClient.ConsentStatus {
        @Dependency(\.analyticsClient) var analytics

        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = config.taggedForUnderAgeOfConsent
        applyDebugSettings(config, to: parameters)

        try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)

        let status = ConsentInformation.shared.consentStatus
        let formAvailable = ConsentInformation.shared.formStatus == .available
        #if DEBUG
        print(
            "🔍 [UMP] post-update consentStatus=\(status.rawValue) formStatus=\(ConsentInformation.shared.formStatus.rawValue) canRequestAds=\(ConsentInformation.shared.canRequestAds)"
        )
        #endif

        guard formAvailable, status == .required || status == .unknown else {
            return mapStatus(status)
        }

        let form = try await loadConsentForm()
        try await presentForm(form)

        let finalStatus = ConsentInformation.shared.consentStatus
        #if DEBUG
        print(
            "🔍 [UMP] post-present consentStatus=\(finalStatus.rawValue) canRequestAds=\(ConsentInformation.shared.canRequestAds)"
        )
        #endif

        // Reported to analytics because the consent decision is itself a funnel signal —
        // this is why the package depends on AnalyticsClient at all.
        if finalStatus == .obtained {
            await analytics.trackEvent("user_consent", [:])
            #if DEBUG
            print("✅ [UMP] User completed consent")
            #endif
        } else {
            await analytics.trackEvent("user_not_consent", [:])
            #if DEBUG
            print("❌ [UMP] User dismissed or did not complete")
            #endif
        }
        return mapStatus(finalStatus)
    }

    static func canRequestAds() -> Bool {
        ConsentInformation.shared.canRequestAds
    }

    static func reset() {
        ConsentInformation.shared.reset()
    }

    /// Sets `RequestParameters.debugSettings` on a three-tier waterfall:
    ///
    /// 1. `forceConsentFormForQA` → force `.EEA` for every device, in every configuration
    ///    (production kill-switch; revert before shipping).
    /// 2. `testDeviceIdentifiers` non-empty → force `.EEA` for the listed UUIDs only
    ///    (scalpel, safe to leave committed).
    /// 3. `#if DEBUG` fallback → force `.EEA` with no device list, so simulators (which are
    ///    auto-registered test devices) always see the form.
    ///
    /// In Release with both overrides off, `debugSettings` stays `nil` and UMP uses real IP
    /// geography — the correct production path.
    private static func applyDebugSettings(
        _ config: ConsentClient.Config,
        to parameters: RequestParameters
    ) {
        if config.forceConsentFormForQA {
            parameters.debugSettings = eeaDebugSettings(testDeviceIdentifiers: [])
            #if DEBUG
            print(
                "🔍 [UMP] forceConsentFormForQA=true; forcing geography=.EEA for ALL devices. Revert before shipping."
            )
            #endif
        } else if !config.testDeviceIdentifiers.isEmpty {
            parameters.debugSettings = eeaDebugSettings(testDeviceIdentifiers: config.testDeviceIdentifiers)
            #if DEBUG
            print(
                "🔍 [UMP] Test-device override active (\(config.testDeviceIdentifiers.count) devices); forcing geography=.EEA."
            )
            #endif
        } else {
            #if DEBUG
            parameters.debugSettings = eeaDebugSettings(testDeviceIdentifiers: [])
            print(
                "🔍 [UMP] DEBUG build: forcing geography=.EEA. Simulators are test devices by default; pass ConsentClient.Config(testDeviceIdentifiers: […]) for physical devices."
            )
            #endif
        }
    }

    /// Debug settings that make UMP treat the request as coming from the EEA — for every
    /// device when `testDeviceIdentifiers` is empty, otherwise only for the listed ones.
    private static func eeaDebugSettings(testDeviceIdentifiers: [String]) -> DebugSettings {
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        debugSettings.testDeviceIdentifiers = testDeviceIdentifiers
        return debugSettings
    }

    /// Uses the raw ObjC name to avoid the `ConsentStatus` name collision.
    private static func mapStatus(
        _ status: UserMessagingPlatform.ConsentStatus
    ) -> ConsentClient.ConsentStatus {
        switch status {
            case .notRequired: return .notRequired
            case .required: return .required
            case .obtained: return .obtained
            case .unknown: fallthrough
            @unknown default: return .unknown
        }
    }

    @MainActor
    private static func loadConsentForm() async throws -> ConsentForm {
        try await withCheckedThrowingContinuation { continuation in
            ConsentForm.load { form, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let form {
                    continuation.resume(returning: form)
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "ConsentClient",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Consent form not available"]
                        )
                    )
                }
            }
        }
    }

    @MainActor
    private static func presentForm(_ form: ConsentForm) async throws {
        let presenter = try topViewController()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            form.present(from: presenter) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// The controller the form presents from: the top of the modal stack, because a
    /// controller that is already presenting refuses to present again and the form
    /// would never appear. Prefers the foreground scene's key window, falling back to
    /// its frontmost normal-level window while launch has not made one key yet.
    @MainActor
    private static func topViewController() throws -> UIViewController {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let keyWindow = scene?.windows.first { $0.isKeyWindow && $0.rootViewController != nil }
        let window = keyWindow ?? scene?.windows.last { $0.windowLevel == .normal && $0.rootViewController != nil }
        guard var top = window?.rootViewController else {
            throw NSError(
                domain: "ConsentClient",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No root view controller found"]
            )
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
