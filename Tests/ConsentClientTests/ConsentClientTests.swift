// The funnel conformance tests next door compile only with the `Funnel` trait on, and that
// trait is off by default — so without this file the default `swift test` would run zero
// tests. These cover the interface every consumer gets whether or not it asks for the
// funnel: the ATT status mapping and the QA kill-switch defaults in `Config`.
import ConsentClient
import Testing

@Suite("ConsentClient")
struct ConsentClientTests {

    @Test("only .authorized counts as authorized")
    func isAuthorizedIsExactlyTheAuthorizedCase() {
        let authorized = ConsentClient.TrackingAuthorization.allCases.filter(\.isAuthorized)

        #expect(authorized == [.authorized])
    }

    /// The raw values mirror `ATTrackingManager.AuthorizationStatus`, and the enum is
    /// `Int`-backed and public — so they are API, not an implementation detail: a host that
    /// persists or transmits one is entitled to the wire numbering. Nothing in this package
    /// maps by them (`ATTActor.map` switches on case names), so a renumbering would not
    /// break the mapping — it would break whoever stored the old number.
    @Test("raw values match ATTrackingManager's status numbering")
    func rawValuesMatchATT() {
        #expect(ConsentClient.TrackingAuthorization.notDetermined.rawValue == 0)
        #expect(ConsentClient.TrackingAuthorization.restricted.rawValue == 1)
        #expect(ConsentClient.TrackingAuthorization.denied.rawValue == 2)
        #expect(ConsentClient.TrackingAuthorization.authorized.rawValue == 3)
    }

    /// `forceConsentFormForQA` shows an EEA consent form to users who are not in the EEA, so
    /// a default that shipped as `true` would be a submission-blocking bug. The default is
    /// the thing worth pinning, not the setter.
    @Test("Config defaults leave every QA override off")
    func configDefaultsAreInert() {
        let config = ConsentClient.Config()

        #expect(config.forceConsentFormForQA == false)
        #expect(config.testDeviceIdentifiers.isEmpty)
        #expect(config.taggedForUnderAgeOfConsent == false)
    }

    /// `.denied` is what a host wires up to rehearse a refusing user, so what it answers is a
    /// contract and not an implementation detail: a mock that reported `canRequestAds == true`
    /// would let a test suite prove an ads path works against permission the user withheld.
    ///
    /// The unconfigured `ConsentClient()` is deliberately not tested here. `@DependencyClient`
    /// makes each unwired closure report "Unimplemented" and fail the test that calls it,
    /// which is the macro's contract rather than this package's.
    @Test("the denied mock refuses both halves of consent")
    func deniedMockFailsClosed() async throws {
        let client = ConsentClient.denied

        #expect(client.trackingAuthorization() == .denied)
        #expect(await client.requestTrackingAuthorization() == .denied)
        #expect(await client.canRequestAds() == false)
        #expect(try await client.requestAdsConsent(ConsentClient.Config()) == .required)
    }

    @Test("the granted mock allows both halves of consent")
    func grantedMockAllowsBoth() async throws {
        let client = ConsentClient.granted

        #expect(client.trackingAuthorization() == .authorized)
        #expect(await client.requestTrackingAuthorization() == .authorized)
        #expect(await client.canRequestAds())
        #expect(try await client.requestAdsConsent(ConsentClient.Config()) == .obtained)
    }
}
