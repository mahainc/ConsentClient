import AppTrackingTransparency
import ConsentClient

#if canImport(UIKit)
import UIKit
#endif

/// Owns the ATT prompt sequencing.
///
/// Isolated so the "wait for `.active`, then prompt once" flow is serialized: concurrent
/// requests funnel through the same actor and the `.notDetermined` guard keeps the system
/// prompt from being requested twice.
actor ATTActor {
    static let shared = ATTActor()

    /// The current system status, mapped to the client's framework-agnostic mirror.
    nonisolated func authorizationStatus() -> ConsentClient.TrackingAuthorization {
        Self.map(ATTrackingManager.trackingAuthorizationStatus)
    }

    /// Requests authorization and returns the authoritative status.
    ///
    /// Fast-paths any already-determined status — iOS shows the prompt once per install, so
    /// asking again is a no-op that would only cost a wait. Otherwise waits until the app is
    /// `.active` (iOS only shows the prompt in that state), then returns the status handed to
    /// the **completion handler**: re-reading the global status right after the prompt is
    /// unreliable, notably on Simulator.
    func requestAuthorization() async -> ConsentClient.TrackingAuthorization {
        let current = ATTrackingManager.trackingAuthorizationStatus
        guard current == .notDetermined else { return Self.map(current) }
        await Self.waitUntilActive()
        let status: ATTrackingManager.AuthorizationStatus = await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { continuation.resume(returning: $0) }
        }
        return Self.map(status)
    }

    private static func map(
        _ status: ATTrackingManager.AuthorizationStatus
    ) -> ConsentClient.TrackingAuthorization {
        switch status {
            case .notDetermined: return .notDetermined
            case .restricted: return .restricted
            case .denied: return .denied
            case .authorized: return .authorized
            @unknown default: return .notDetermined
        }
    }

    /// Suspends until the app reaches `UIApplication.State.active`.
    ///
    /// Returns immediately if already active; otherwise polls with a bounded cap so a missed
    /// transition cannot hang the caller forever. A short poll loop sidesteps the Swift 6
    /// region-isolation pitfalls of bridging an `AsyncStream` notification iterator across a
    /// task group. No-op on platforms without `UIApplication`.
    @MainActor
    private static func waitUntilActive() async {
        #if canImport(UIKit)
        // ~3s cap (60 × 50ms) — comfortably outlasts a normal cold-launch settle without
        // blocking indefinitely.
        for _ in 0..<60 {
            if UIApplication.shared.applicationState == .active { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        #endif
    }
}
