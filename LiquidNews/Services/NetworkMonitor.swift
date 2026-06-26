// NetworkMonitor.swift
// Shared connectivity state. Drives the offline banner, offline-mode gating of network
// actions, and HNAPIService's WiFi/cellular concurrency choice.

import Foundation
import Network
import Observation
import os

@Observable
@MainActor
final class NetworkMonitor {

    // Nonisolated so actors and other non-main contexts can reach the singleton and
    // read the snapshot without a main-actor hop.
    nonisolated static let shared = NetworkMonitor()

    // SwiftUI-observable state, updated on the main actor (drives banner + gating).
    private(set) var isOnline: Bool = true
    private(set) var isOnWifi: Bool = true

    // Race-free snapshot for non-main callers (e.g. HNAPIService.maxConcurrentFetches),
    // written from the NWPathMonitor background queue. A lock — NOT nonisolated(unsafe) —
    // so this does not reintroduce the data race the cache project set out to remove.
    nonisolated private struct Connectivity { var online = true; var wifi = true }
    nonisolated private let snapshot = OSAllocatedUnfairLock(initialState: Connectivity())

    nonisolated func currentlyOnWifi() -> Bool { snapshot.withLock { $0.wifi } }
    nonisolated func currentlyOnline() -> Bool { snapshot.withLock { $0.online } }

    private let monitor = NWPathMonitor()

    nonisolated private init() {
        monitor.pathUpdateHandler = { [snapshot] path in
            let online = path.status == .satisfied
            let wifi = path.usesInterfaceType(.wifi)
            snapshot.withLock { $0 = Connectivity(online: online, wifi: wifi) }
            Task { @MainActor in
                NetworkMonitor.shared.isOnline = online
                NetworkMonitor.shared.isOnWifi = wifi
            }
        }
        monitor.start(queue: .global(qos: .utility))
    }
}
