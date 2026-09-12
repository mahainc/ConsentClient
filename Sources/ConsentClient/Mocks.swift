import Dependencies

extension DependencyValues {
    public var consentClient: ConsentClient {
        get { self[ConsentClient.self] }
        set { self[ConsentClient.self] = newValue }
    }
}

extension ConsentClient: TestDependencyKey {
    public static let testValue = Self()
    public static let previewValue = Self.granted
}

extension ConsentClient {
    /// Everything allowed — the shape a host sees from a consenting EEA user.
    public static let granted = Self(
        trackingAuthorization: { .authorized },
        requestTrackingAuthorization: { .authorized },
        requestAdsConsent: { _ in .obtained },
        canRequestAds: { true },
        resetAdsConsent: {},
        configuration: { Config() }
    )

    /// The user refused both halves.
    public static let denied = Self(
        trackingAuthorization: { .denied },
        requestTrackingAuthorization: { .denied },
        requestAdsConsent: { _ in .required },
        canRequestAds: { false },
        resetAdsConsent: {},
        configuration: { Config() }
    )
}
