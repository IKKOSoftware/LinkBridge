//
//  main.swift
//  link-bridge
//
//  Ableton Link in a process of its own. Serves the shared timeline over gRPC on a Unix socket (see
//  Protos/link_bridge.proto) to the app that started it, and quits when that app does.
//
//      link-bridge --socket <path> [--parent <pid>] [--tempo <bpm>]
//
//  GPL v2 or later, like Link: see COPYING.md.
//

import CLink
import Dispatch
import Foundation
import GRPC
import LinkBridgeProtocol
import NIOCore
import NIOPosix

// MARK: - Arguments

var arguments: [String: String] = [:]
var index = 1
while index < CommandLine.arguments.count {
    let key = CommandLine.arguments[index]
    if key.hasPrefix("--"), index + 1 < CommandLine.arguments.count {
        arguments[String(key.dropFirst(2))] = CommandLine.arguments[index + 1]
        index += 2
    } else {
        index += 1
    }
}

guard let socket = arguments["socket"] else {
    FileHandle.standardError.write("usage: link-bridge --socket <path> [--parent <pid>] [--tempo <bpm>]\n".data(using: .utf8)!)
    exit(64)
}

// MARK: - Link

/// Link and the settings the client gave it. Link's own API is safe from any thread; the lock keeps the settings and
/// the last applied request together.
final class Bridge: @unchecked Sendable {
    private let link: OpaquePointer
    private let lock = NSLock()
    private var quantum = 4.0
    private var applied: UInt64 = 0

    init(tempo: Double) {
        link = s8link_create(tempo)
    }

    deinit {
        s8link_destroy(link)
    }

    func configure(_ settings: Linkbridge_Settings) -> Linkbridge_Timeline {
        lock.withLock {
            quantum = max(1, settings.quantum)
            s8link_enable(link, settings.enabled)
            s8link_enable_start_stop_sync(link, settings.startStopSync)
            applied = max(applied, settings.sequence)
        }
        return timeline()
    }

    func setTempo(_ request: Linkbridge_SetTempoRequest) -> Linkbridge_Timeline {
        lock.withLock {
            s8link_set_tempo(link, min(max(request.bpm, 20), 999), s8link_clock_micros(link))
            applied = max(applied, request.sequence)
        }
        return timeline()
    }

    func setPlaying(_ request: Linkbridge_SetPlayingRequest) -> Linkbridge_Timeline {
        lock.withLock {
            s8link_set_playing(link, request.playing, s8link_clock_micros(link))
            applied = max(applied, request.sequence)
        }
        return timeline()
    }

    /// The timeline now, stamped with the uptime it was captured at.
    func timeline() -> Linkbridge_Timeline {
        lock.withLock {
            let uptime = DispatchTime.now().uptimeNanoseconds
            let state = s8link_capture(link, s8link_clock_micros(link), quantum)
            var timeline = Linkbridge_Timeline()
            timeline.enabled = s8link_is_enabled(link)
            timeline.startStopSync = s8link_is_start_stop_sync_enabled(link)
            timeline.quantum = quantum
            timeline.tempo = state.tempo
            timeline.beat = state.beat
            timeline.uptimeNanos = uptime
            timeline.isPlaying = state.is_playing
            timeline.peers = UInt32(clamping: s8link_num_peers(link))
            timeline.applied = applied
            return timeline
        }
    }
}

// MARK: - Service

final class Service: Linkbridge_LinkBridgeAsyncProvider {
    let bridge: Bridge

    init(bridge: Bridge) {
        self.bridge = bridge
    }

    func configure(request: Linkbridge_Settings, context: GRPCAsyncServerCallContext) async throws -> Linkbridge_Timeline {
        bridge.configure(request)
    }

    func setTempo(request: Linkbridge_SetTempoRequest, context: GRPCAsyncServerCallContext) async throws -> Linkbridge_Timeline {
        bridge.setTempo(request)
    }

    func setPlaying(request: Linkbridge_SetPlayingRequest, context: GRPCAsyncServerCallContext) async throws -> Linkbridge_Timeline {
        bridge.setPlaying(request)
    }

    func watch(request: Linkbridge_WatchRequest, responseStream: GRPCAsyncResponseStreamWriter<Linkbridge_Timeline>, context: GRPCAsyncServerCallContext) async throws {
        let interval = UInt64(min(max(request.intervalMs, 2), 1000)) * 1_000_000
        while !Task.isCancelled {
            try await responseStream.send(bridge.timeline())
            try await Task.sleep(nanoseconds: interval)
        }
    }
}

// MARK: - Running

let bridge = Bridge(tempo: arguments["tempo"].flatMap(Double.init) ?? 120)

// Quit with the app that started it, however it ends
var parentWatcher: (any DispatchSourceProcess)?
if let parent = arguments["parent"].flatMap(pid_t.init) {
    if kill(parent, 0) != 0 { exit(0) }
    parentWatcher = DispatchSource.makeProcessSource(identifier: parent, eventMask: .exit, queue: .main)
    parentWatcher?.setEventHandler { exit(0) }
    parentWatcher?.resume()
}
signal(SIGTERM) { _ in exit(0) }
signal(SIGINT) { _ in exit(0) }

// A socket left by a bridge that didn't get to clean up
unlink(socket)
atexit { if let socket = arguments["socket"] { unlink(socket) } }

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
do {
    let server = try Server.insecure(group: group)
        .withServiceProviders([Service(bridge: bridge)])
        .bind(unixDomainSocketPath: socket)
        .wait()
    // Said once it can be connected to, for whoever started it
    print("ready")
    fflush(stdout)
    _ = server
} catch {
    FileHandle.standardError.write("link-bridge: couldn't listen on \(socket): \(error)\n".data(using: .utf8)!)
    exit(1)
}

dispatchMain()
