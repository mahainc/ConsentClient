import ConsentClient
import ConsentClientLive
import FunnelClient
import Testing

@Suite("ConsentClient funnel conformance")
struct ConsentConformanceTests {

    @Test("resolves ATT before UMP")
    func trackingPromptPrecedesAdsConsent() async {
        let stubs = ConsentStubs()

        _ = await stubs.client.requestConsentIfNeeded()

        let steps = await stubs.recorder.steps
        #expect(steps == [.tracking, .ads])
    }

    @Test("a thrown UMP request falls back to the cached canRequestAds")
    func thrownRequestFallsBackToCachedDecision() async {
        var stubs = ConsentStubs()
        stubs.umpError = .unreachable
        stubs.canRequestAds = true

        let outcome = await stubs.client.requestConsentIfNeeded()

        #expect(outcome.canRequestAds)
    }

    @Test(
        "never reports .unavailable — ATT always yields a real answer",
        arguments: ConsentClient.TrackingAuthorization.allCases
    )
    func neverReportsUnavailable(status: ConsentClient.TrackingAuthorization) async {
        var stubs = ConsentStubs()
        stubs.tracking = status

        let outcome = await stubs.client.requestConsentIfNeeded()

        if case .unavailable = outcome.trackingAuthorization {
            Issue.record("ATT status \(status) collapsed to .unavailable")
        }
    }
}

// MARK: - Stubs

private enum ConsentStep: Equatable {
    case tracking
    case ads
}

private enum StubError: Error {
    case unreachable
}

private actor StepRecorder {
    private(set) var steps: [ConsentStep] = []

    func record(_ step: ConsentStep) {
        steps.append(step)
    }
}

/// One stub for the whole flow, where the previous shape needed two clients stitched
/// together through `withDependencies` — the merge shows up here as well.
private struct ConsentStubs: Sendable {
    var tracking: ConsentClient.TrackingAuthorization = .authorized
    var umpError: StubError?
    var canRequestAds = true
    var recorder = StepRecorder()

    var client: ConsentClient {
        ConsentClient(
            trackingAuthorization: { tracking },
            requestTrackingAuthorization: {
                await recorder.record(.tracking)
                return tracking
            },
            requestAdsConsent: { _ in
                await recorder.record(.ads)
                if let umpError {
                    throw umpError
                }
                return .obtained
            },
            canRequestAds: { canRequestAds },
            resetAdsConsent: {},
            configuration: { ConsentClient.Config() }
        )
    }
}
