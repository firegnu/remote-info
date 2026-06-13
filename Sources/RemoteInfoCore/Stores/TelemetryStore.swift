import Combine
import Foundation

public struct HostState: Equatable, Identifiable, Sendable {
    public let host: HostConfig
    public var telemetry: HostTelemetry?
    public var status: TelemetryStatus
    public var isRefreshing: Bool

    public var id: String {
        host.id
    }

    public init(
        host: HostConfig,
        telemetry: HostTelemetry? = nil,
        status: TelemetryStatus = .idle,
        isRefreshing: Bool = false
    ) {
        self.host = host
        self.telemetry = telemetry
        self.status = status
        self.isRefreshing = isRefreshing
    }
}

@MainActor
public final class TelemetryStore: ObservableObject {
    public static let defaultPeriodicRefreshInterval: TimeInterval = 300
    public static let defaultStaleTelemetryInterval: TimeInterval = 600
    public static let defaultStaleStatusUpdateInterval: TimeInterval = 60

    @Published public private(set) var hostStates: [HostState]
    @Published public private(set) var lastRefreshStartedAt: Date?

    private let collector: any TelemetryCollecting
    private let staleTelemetryInterval: TimeInterval
    private var periodicRefreshTask: Task<Void, Never>?
    private var staleStatusTask: Task<Void, Never>?

    public init(
        hosts: [HostConfig],
        collector: any TelemetryCollecting = TelemetryCollector(),
        staleTelemetryInterval: TimeInterval = defaultStaleTelemetryInterval
    ) {
        self.hostStates = hosts.map { HostState(host: $0) }
        self.collector = collector
        self.staleTelemetryInterval = staleTelemetryInterval
    }

    deinit {
        periodicRefreshTask?.cancel()
        staleStatusTask?.cancel()
    }

    public var onlineCount: Int {
        hostStates.filter { state in
            state.status == .online || state.status == .stale
        }.count
    }

    public var errorCount: Int {
        hostStates.filter { state in
            if case .offline = state.status {
                return true
            }
            return false
        }.count
    }

    public func refreshAll() async {
        updateStaleStatuses()
        lastRefreshStartedAt = Date()
        let refreshRequests = hostStates.indices.compactMap { index -> HostRefreshRequest? in
            if hostStates[index].isRefreshing {
                return nil
            }

            hostStates[index].isRefreshing = true
            hostStates[index].status = .loading
            return HostRefreshRequest(index: index, host: hostStates[index].host)
        }

        let collector = collector
        await withTaskGroup(of: HostRefreshResult.self) { group in
            for request in refreshRequests {
                group.addTask {
                    do {
                        let telemetry = try await collector.collect(for: request.host)
                        return HostRefreshResult(index: request.index, outcome: .success(telemetry))
                    } catch {
                        return HostRefreshResult(index: request.index, outcome: .failure(error.localizedDescription))
                    }
                }
            }

            for await result in group {
                switch result.outcome {
                case .success(let telemetry):
                    hostStates[result.index].telemetry = telemetry
                    hostStates[result.index].status = .online
                case .failure(let message):
                    hostStates[result.index].status = .offline(message)
                }

                hostStates[result.index].isRefreshing = false
            }
        }
    }

    public func updateStaleStatuses(asOf date: Date = Date()) {
        for index in hostStates.indices {
            guard let telemetry = hostStates[index].telemetry else {
                continue
            }

            switch hostStates[index].status {
            case .online, .stale:
                let age = date.timeIntervalSince(telemetry.collectedAt)
                hostStates[index].status = age > staleTelemetryInterval ? .stale : .online
            case .idle, .loading, .offline:
                continue
            }
        }
    }

    public func startPeriodicRefresh(
        every seconds: TimeInterval = defaultPeriodicRefreshInterval,
        staleStatusUpdateInterval: TimeInterval = defaultStaleStatusUpdateInterval
    ) {
        stopPeriodicRefresh()

        guard seconds > 0 else {
            return
        }

        startStaleStatusUpdates(every: staleStatusUpdateInterval)

        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)

                if Task.isCancelled {
                    break
                }

                await self?.refreshAll()
            }
        }
    }

    public func stopPeriodicRefresh() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil
        staleStatusTask?.cancel()
        staleStatusTask = nil
    }

    private func startStaleStatusUpdates(every seconds: TimeInterval) {
        guard seconds > 0 else {
            return
        }

        staleStatusTask = Task { [weak self] in
            while !Task.isCancelled {
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)

                if Task.isCancelled {
                    break
                }

                self?.updateStaleStatuses()
            }
        }
    }

}

private struct HostRefreshRequest: Sendable {
    let index: Int
    let host: HostConfig
}

private struct HostRefreshResult: Sendable {
    let index: Int
    let outcome: HostRefreshOutcome
}

private enum HostRefreshOutcome: Sendable {
    case success(HostTelemetry)
    case failure(String)
}
