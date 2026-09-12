import ConsentClient
import Dependencies

extension ConsentClient: DependencyKey {
    public static let liveValue: Self = live()

    /// - Parameter configuration: UMP knobs the port's own method signature cannot carry —
    ///   the QA form override, the test-device list, and the COPPA flag.
    public static func live(configuration: Config = Config()) -> Self {
        Self(
            trackingAuthorization: {
                ATTActor.shared.authorizationStatus()
            },
            requestTrackingAuthorization: {
                await ATTActor.shared.requestAuthorization()
            },
            requestAdsConsent: { config in
                try await UMPFlow.requestConsent(config)
            },
            canRequestAds: {
                UMPFlow.canRequestAds()
            },
            resetAdsConsent: {
                UMPFlow.reset()
            },
            configuration: { configuration }
        )
    }
}
