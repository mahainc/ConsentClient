import ATTClient
import ATTClientLive
import Testing
import UMPClient
import UMPClientLive

/// Guards the mistake that shipped in 1.0.0 and 1.0.1.
///
/// `ConsentClientLive` linked only the *interface* targets of ATTClient and UMPClient. That
/// compiles: `@Dependency(\.umpClient)` resolves fine at build time. At runtime the
/// `liveValue` simply is not in the binary, so every call landed on the `@DependencyClient`
/// unimplemented stub and the provider answered `canRequestAds = false` for every user —
/// no ads requested, no ATT prompt, all revenue gone, and nothing in the logs but a
/// `DependenciesMacros.Unimplemented` error.
///
/// The existing behaviour tests cannot catch it: they inject stubs through
/// `withDependencies`, so they never touch `liveValue` at all. This one does nothing but
/// name the live values, which fails to **compile** if the Live products stop being linked.
@Suite("Live values are linked")
struct LiveValueLinkTests {

    @Test("ATTClient and UMPClient live implementations are reachable")
    func liveValuesResolve() {
        _ = ATTClient.liveValue
        _ = UMPClient.liveValue
    }
}
