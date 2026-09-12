import ATTClient
import ConsentClientLive
import Dependencies
import FunnelClient
import Testing
import UMPClient

@Suite("ConsentFunnelProvider")
struct ConsentFunnelProviderTests {

    @Test("resolves ATT before UMP")
    func trackingPromptPrecedesAdsConsent() async {
        let stubs = ConsentStubs()

        _ = await resolveOutcome(stubs)

        let steps = await stubs.recorder.steps
        #expect(steps == [.tracking, .ads])
    }

    @Test("a thrown UMP request falls back to the cached canRequestAds")
    func thrownRequestFallsBackToCachedDecision() async {
        var stubs = ConsentStubs()
        stubs.umpError = .unreachable
        stubs.canRequestAds = true

        let outcome = await resolveOutcome(stubs)

        #expect(outcome.canRequestAds)
    }

    @Test(
        "never reports .unavailable — ATT always yields a real answer",
        arguments: ATTClient.AuthorizationStatus.allCases
    )
    func neverReportsUnavailable(status: ATTClient.AuthorizationStatus) async {
        var stubs = ConsentStubs()
        stubs.tracking = status

        let outcome = await resolveOutcome(stubs)

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

private struct ConsentStubs: Sendable {
    var tracking: ATTClient.AuthorizationStatus = .authorized
    var umpError: StubError?
    var canRequestAds = true
    var recorder = StepRecorder()

    var attClient: ATTClient {
        ATTClient(
            authorizationStatus: { tracking },
            requestAuthorization: {
                await recorder.record(.tracking)
                return tracking
            }
        )
    }

    var umpClient: UMPClient {
        UMPClient(
            requestConsentIfNeeded: { _ in
                await recorder.record(.ads)
                if let umpError {
                    throw umpError
                }
                return .obtained
            },
            consentStatus: { .obtained },
            canRequestAds: { canRequestAds },
            reset: {}
        )
    }
}

/// Runs the provider against `stubs`, recording the order the two halves ran in.
private func resolveOutcome(_ stubs: ConsentStubs) async -> FunnelClient.Consent.Outcome {
    await withDependencies {
        $0.attClient = stubs.attClient
        $0.umpClient = stubs.umpClient
    } operation: {
        await ConsentFunnelProvider().requestConsentIfNeeded()
    }
}
