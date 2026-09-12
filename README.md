# ConsentClient

The composed ATT + UMP consent flow, and the conformer that serves
`FunnelClient.Consent.Providing` from it.

## Why the package exists

`FunnelClient`'s consent port wants **one** answer containing both halves of consent:
Apple's tracking authorization and Google's "may I request ads" decision. Those halves
live in two separate packages — [`ATTClient`](https://github.com/mahainc/ATTClient) and
[`UMPClient`](https://github.com/mahainc/UMPClient) — and neither knows the other exists,
so neither can conform to the port alone.

## Targets

| Target | What it holds |
|---|---|
| `ConsentClient` | Configuration only. Never links FunnelClient, so a caller can describe its consent policy without depending on the funnel. |
| `ConsentClientLive` | `ConsentFunnelProvider` — the conformer. |

## The ordering guarantee

ATT is resolved **before** UMP, with sequential `await`s rather than `async let`. This is
enforced by the flow, not left to the caller, for two reasons: Apple's prompt has to be
answered before Google's form appears so UMP's disclosure reflects the decision the user
just made, and two modal system dialogs cannot share the screen.

## Failing soft

The port cannot throw, and an unreachable consent backend must not cost the host its ad
revenue. A thrown UMP request is logged and the answer falls back to `canRequestAds()`,
which UMP serves from its own cached decision.

`TrackingAuthorization.unavailable` is deliberately never produced here. The port reserves
it for a host that runs no consent layer at all; this provider always asks, on a platform
where ATT always exists, so every answer it returns is a real one.

## Usage

```swift
import ConsentClientLive
import FunnelClient

let consent = ConsentFunnelProvider()

$0.funnel = .live(
    consent: consent
    // …other ports
)
```

Pass a `ConsentClient.Config` to override the UMP knobs (QA form forcing, test device
identifiers, the COPPA flag).
