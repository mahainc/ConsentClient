import DependenciesMacros
import Foundation

/// The composed ATT + UMP consent flow.
///
/// `FunnelClient.Consent.Providing` needs both halves of consent in one answer — Apple's
/// tracking authorization and Google's "may I request ads" decision. They used to live in
/// two separate packages that this one wrapped; both are implemented directly here now, so
/// there is one place to read when the flow misbehaves instead of three.
///
/// This target stays free of FunnelClient: the port conformance lives in `ConsentClientLive`,
/// so a caller can describe its consent policy without depending on the funnel.
@DependencyClient
public struct ConsentClient: Sendable {
    /// The current ATT status, without prompting.
    public var trackingAuthorization: @Sendable () -> TrackingAuthorization = { .notDetermined }

    /// Prompts for ATT if, and only if, the status is still undetermined.
    public var requestTrackingAuthorization: @Sendable () async -> TrackingAuthorization = {
        .notDetermined
    }

    /// Runs Google's consent-information update and presents the form when one is required.
    public var requestAdsConsent: @Sendable (_ config: Config) async throws -> ConsentStatus

    /// Google's authoritative answer to "may I request ads", served from its cached decision.
    public var canRequestAds: @Sendable () async -> Bool = { false }

    /// Clears the cached UMP decision. Debug affordance — a shipped app never calls it.
    public var resetAdsConsent: @Sendable () async -> Void

    /// Host-bound configuration the port's own method signature cannot carry.
    public var configuration: @Sendable () -> Config = { Config() }
}

extension ConsentClient {
    /// Apple's four ATT states, mirrored so this package does not export
    /// `AppTrackingTransparency` types to its callers.
    ///
    /// Raw values are locked to Apple's enum.
    public enum TrackingAuthorization: Int, Equatable, Sendable, CaseIterable {
        case notDetermined = 0
        case restricted = 1
        case denied = 2
        case authorized = 3

        public var isAuthorized: Bool { self == .authorized }
    }

    /// Google's consent states.
    public enum ConsentStatus: Sendable, Equatable {
        case unknown
        case required
        case notRequired
        case obtained
    }

    public struct Config: Sendable, Equatable {
        /// Forces the consent form to appear on **every** device, in every build
        /// configuration, by pretending the user is in the EEA.
        ///
        /// A QA kill-switch. It **must be `false` before any App Store submission** — leaving
        /// it on shows an EEA consent form to users who are not in the EEA.
        public let forceConsentFormForQA: Bool

        /// Forces the form for these device identifiers only, in any build configuration.
        ///
        /// The scalpel version of `forceConsentFormForQA`, safe to leave committed. A
        /// simulator is a registered test device automatically; a physical device is not,
        /// which is why its form silently never appears until its UUID is listed here. The
        /// UMP SDK prints the identifier to the console on first run.
        public let testDeviceIdentifiers: [String]

        /// Tags the request as coming from a user under the age of consent (COPPA).
        public let taggedForUnderAgeOfConsent: Bool

        public init(
            forceConsentFormForQA: Bool = false,
            testDeviceIdentifiers: [String] = [],
            taggedForUnderAgeOfConsent: Bool = false
        ) {
            self.forceConsentFormForQA = forceConsentFormForQA
            self.testDeviceIdentifiers = testDeviceIdentifiers
            self.taggedForUnderAgeOfConsent = taggedForUnderAgeOfConsent
        }
    }
}
