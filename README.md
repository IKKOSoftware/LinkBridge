# LinkBridge

[Ableton Link](https://github.com/Ableton/link) in a process of its own, serving the shared timeline (tempo, beats and
start/stop) to an app over gRPC on a local Unix socket. It's how SUBSTR8 plays in time with Live and other Link apps.

LinkBridge is free software under the **GNU GPL v2 or later**, like Link itself: see [COPYING.md](COPYING.md). The
protocol, [Protos/link_bridge.proto](Protos/link_bridge.proto), is **MIT** licensed, so any app can generate a client
from it.

## Running it

    swift build -c release
    .build/release/link-bridge --socket /tmp/link.sock [--parent <pid>] [--tempo <bpm>]

It prints `ready` once it's listening. With `--parent` it quits when that process does, so an app can start it and
forget about it.

## The protocol

| Call | |
|---|---|
| `Configure(Settings)` | Join or leave the session, share start/stop, set the bar length (quantum). |
| `SetTempo`, `SetPlaying` | Change the session's tempo, or start or stop it (with start/stop shared). |
| `Watch` | The timeline every few milliseconds, for as long as the call is open. |

Every reply is a `Timeline`: the tempo, the beat at a moment, and that moment in uptime nanoseconds (the mach clock,
the same in every process). A client works out the beat at any time from the latest one without asking again:

    beat(now) = timeline.beat + (now - timeline.uptime_nanos) / 60e9 * timeline.tempo

Requests carry an increasing `sequence` and each `Timeline` says the last one it has `applied`, so a client can change
the tempo locally straight away and ignore any timeline from before the helper caught up.

## Changing the protocol

Edit `Protos/link_bridge.proto` and run `Scripts/generate.sh`, which builds the code generators and writes
`Sources/LinkBridgeProtocol`. `Scripts/generate.sh --client <dir>` also writes a client (and a copy of the protocol) to
`<dir>`: SUBSTR8's is in `SUBSTR8Core/Sources/SUBSTR8Link/LinkBridge`.

## What's vendored

- `Sources/CLink/vendor/link`: Ableton Link (GPL v2+), at the commit in its `VERSION` file.
- `Sources/CLink/vendor/asio`: ASIO (Boost Software Licence), which Link uses.
- `Sources/CLink/s8link.*`: a small C interface to Link, so Swift can use it.
