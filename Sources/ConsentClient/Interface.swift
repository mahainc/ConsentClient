import UMPClient

/// Namespace for the composed ATT + UMP consent flow.
///
/// The package exists because `FunnelClient.Consent.Providing` needs both
/// halves of consent in one answer — Apple's tracking authorization and
/// Google's "may I request ads" decision — while each half lives in its own
/// client package. `ConsentClientLive.ConsentFunnelProvider` is the conformer;
/// this target holds only what a caller configures, so it never has to link
/// FunnelClient to describe its consent policy.
public enum ConsentClient {}

extension ConsentClient {
    /// Configuration for the composed flow.
    ///
    /// Every knob belongs to UMP: the ATT prompt is a system dialog that takes
    /// no parameters, and the ordering of the two halves is a guarantee of the
    /// flow rather than a choice a caller makes. Aliasing instead of wrapping
    /// keeps the QA overrides (`forceConsentFormForQA`, `testDeviceIdentifiers`)
    /// and the COPPA flag documented in exactly one place.
    public typealias Config = UMPClient.Config
}
