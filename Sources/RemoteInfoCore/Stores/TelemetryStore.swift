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
    @Published public private(set) var hostStates: [HostState]
    @Published public private(set) var lastRefreshStartedAt: Date?

    private let collector: any TelemetryCollecting
    private var periodicRefreshTask: Task<Void, Never>?

    public init(
        hosts: [HostConfig],
        collector: any TelemetryCollecting = TelemetryCollector()
    ) {
        self.hostStates = hosts.map { HostState(host: $0) }
        self.collector = collector
    }

    deinit {
        periodicRefreshTask?.cancel()
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
        lastRefreshStartedAt = Date()

        for index in hostStates.indices {
            if hostStates[index].isRefreshing {
                continue
            }

            await refreshHost(at: index)
        }
    }

    public func startPeriodicRefresh(every seconds: TimeInterval = 60) {
        stopPeriodicRefresh()

        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshAll()

                let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
        }
    }

    public func stopPeriodicRefresh() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil
    }

    private func refreshHost(at index: Int) async {
        hostStates[index].isRefreshing = true
        hostStates[index].status = .loading

        do {
            let telemetry = try await collector.collect(for: hostStates[index].host)
            hostStates[index].telemetry = telemetry
            hostStates[index].status = .online
        } catch {
            hostStates[index].status = .offline(error.localizedDescription)
        }

        hostStates[index].isRefreshing = false
    }
}
