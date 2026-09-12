import ATTClient
import ConsentClient
import Dependencies
import FunnelClient
import LogClient
import UMPClient

/// Composes `ATTClient` and `UMPClient` into the single consent answer
/// `FunnelClient` asks for.
///
/// Neither client can conform to `FunnelClient.Consent.Providing` alone: the
/// port wants Apple's tracking authorization and Google's "may I request ads"
/// decision in one `Outcome`, and the two live in packages that do not know
/// about each other.
public final class ConsentFunnelProvider: FunnelClient.Consent.Providing {
    private let config: ConsentClient.Config

    public init(config: ConsentClient.Config = ConsentClient.Config()) {
        self.config = config
    }

    /// Resolves both halves of consent, ATT first.
    ///
    /// The order is load-bearing and is enforced here rather than left to a
    /// caller: Apple's prompt must be answered before Google's form appears, so
    /// UMP's disclosure reflects the tracking decision the user has just made,
    /// and two modal system dialogs cannot share the screen. The sequential
    /// `await`s below — never `async let` — are what guarantee it.
    public func requestConsentIfNeeded() async -> FunnelClient.Consent.Outcome {
        let tracking = await requestTrackingAuthorization()
        let canRequestAds = await requestAdsConsent()

        return FunnelClient.Consent.Outcome(
            canRequestAds: canRequestAds,
            trackingAuthorization: tracking
        )
    }

    // MARK: - ATT

    private func requestTrackingAuthorization() async -> FunnelClient.Consent.TrackingAuthorization {
        @Dependency(\.attClient) var attClient
        let status = await attClient.requestAuthorization()
        return Self.trackingAuthorization(from: status)
    }

    /// Maps ATT's four statuses onto the port's five.
    ///
    /// `.unavailable` is deliberately never produced. The port reserves it for
    /// a host that runs no consent layer at all — `Outcome.permissive` and
    /// `Consent.NoopClient` use it to say "ATT does not apply here". This
    /// provider always asks, on a platform where ATT always exists, so every
    /// answer it returns is a real one. Listing the cases exhaustively (no
    /// `default`) keeps a new upstream status a compile error rather than a
    /// silent collapse into `.notDetermined`.
    private static func trackingAuthorization(
        from status: ATTClient.AuthorizationStatus
    ) -> FunnelClient.Consent.TrackingAuthorization {
        switch status {
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
        }
    }

    // MARK: - UMP

    /// Runs the UMP consent flow and reports whether ads may be requested.
    ///
    /// Fails soft, because the port cannot throw and an unreachable consent
    /// backend must not cost the host its ad revenue: a thrown request is
    /// logged and the answer falls back to `canRequestAds()`, which UMP serves
    /// from its own cached decision. The returned `ConsentStatus` is discarded
    /// for the same reason — `canRequestAds` is the authoritative bit, and a
    /// user who is merely `.required` outside the EEA may still be served ads.
    private func requestAdsConsent() async -> Bool {
        @Dependency(\.umpClient) var umpClient

        #if DEBUG
        // Clear the cached decision so every debug run sees the form again.
        await umpClient.reset()
        #endif

        do {
            _ = try await umpClient.requestConsentIfNeeded(config)
        } catch {
            @Dependency(\.logClient) var log
            log.funnel.consent.error("UMP consent request failed: \(error.localizedDescription)")
        }

        return await umpClient.canRequestAds()
    }
}
