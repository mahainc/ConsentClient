import ConsentClient
import Dependencies
import FunnelClient
import LogClient

/// Serves `FunnelClient.Consent.Providing` from the client itself, so a host reaches it
/// through the dependency key it already has — `@Dependency(\.consentClient)`.
extension ConsentClient: FunnelClient.Consent.Providing {
    /// Resolves both halves of consent, ATT first.
    ///
    /// The order is load-bearing and enforced here rather than left to a caller: Apple's
    /// prompt must be answered before Google's form appears, so UMP's disclosure reflects the
    /// tracking decision the user has just made, and two modal system dialogs cannot share
    /// the screen. The sequential `await`s below — never `async let` — are what guarantee it.
    public func requestConsentIfNeeded() async -> FunnelClient.Consent.Outcome {
        let tracking = await requestTrackingAuthorization()
        let canRequestAds = await resolveAdsConsent()

        return FunnelClient.Consent.Outcome(
            canRequestAds: canRequestAds,
            trackingAuthorization: Self.trackingAuthorization(from: tracking)
        )
    }

    /// Runs the UMP flow and reports whether ads may be requested.
    ///
    /// Fails soft, because the port cannot throw and an unreachable consent backend must not
    /// cost the host its ad revenue: a thrown request is logged and the answer falls back to
    /// `canRequestAds()`, which UMP serves from its own cached decision. The returned status
    /// is discarded for the same reason — `canRequestAds` is the authoritative bit, and a
    /// user who is merely `.required` outside the EEA may still be served ads.
    private func resolveAdsConsent() async -> Bool {
        #if DEBUG
        // Clear the cached decision so every debug run sees the form again.
        await resetAdsConsent()
        #endif

        do {
            _ = try await requestAdsConsent(configuration())
        } catch {
            @Dependency(\.logClient) var log
            log.funnel.consent.error("UMP consent request failed: \(error.localizedDescription)")
        }

        return await canRequestAds()
    }

    /// Maps the client's four ATT states onto the port's five.
    ///
    /// `.unavailable` is deliberately never produced. The port reserves it for a host that
    /// runs no consent layer at all — `Outcome.permissive` and `Consent.NoopClient` use it to
    /// say "ATT does not apply here". This client always asks, on a platform where ATT always
    /// exists, so every answer it returns is a real one. Listing the cases exhaustively (no
    /// `default`) keeps a new upstream status a compile error rather than a silent collapse
    /// into `.notDetermined`.
    private static func trackingAuthorization(
        from status: ConsentClient.TrackingAuthorization
    ) -> FunnelClient.Consent.TrackingAuthorization {
        switch status {
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
        }
    }
}
