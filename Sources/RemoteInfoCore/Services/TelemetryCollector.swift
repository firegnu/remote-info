import Foundation

public protocol TelemetryCollecting: Sendable {
    func collect(for host: HostConfig) async throws -> HostTelemetry
}

public struct TelemetryCollector: TelemetryCollecting, Sendable {
    public static let remoteScript = """
    set -eu

    read_cpu() {
      awk '/^cpu / { print $2" "$3" "$4" "$5" "$6" "$7" "$8" "$9 }' /proc/stat
    }

    cpu_before="$(read_cpu)"
    sleep 1
    cpu_after="$(read_cpu)"

    cpu_usage_percent="$(awk -v before="$cpu_before" -v after="$cpu_after" '
    BEGIN {
      split(before, b, " ");
      split(after, a, " ");
      idle_before=b[4]+b[5];
      idle_after=a[4]+a[5];
      total_before=0;
      total_after=0;
      for (i=1; i<=8; i++) {
        total_before += b[i];
        total_after += a[i];
      }
      total_delta=total_after-total_before;
      idle_delta=idle_after-idle_before;
      if (total_delta <= 0) {
        print "0";
      } else {
        printf "%.1f", (100 * (total_delta-idle_delta) / total_delta);
      }
    }')"

    uptime_seconds="$(awk '{ printf "%d", $1 }' /proc/uptime)"
    read load1 load5 load15 _ < /proc/loadavg
    memory_total_bytes="$(awk '/^MemTotal:/ { printf "%.0f", $2 * 1024 }' /proc/meminfo)"
    memory_available_bytes="$(awk '/^MemAvailable:/ { printf "%.0f", $2 * 1024 }' /proc/meminfo)"
    memory_used_bytes="$(awk -v total="$memory_total_bytes" -v available="$memory_available_bytes" 'BEGIN { printf "%.0f", total - available }')"
    root_values="$(df -B1 / | awk 'NR==2 { print $3" "$2 }')"
    root_used_bytes="$(printf "%s" "$root_values" | awk '{ print $1 }')"
    root_total_bytes="$(printf "%s" "$root_values" | awk '{ print $2 }')"
    kernel_release="$(uname -r)"

    printf 'uptime_seconds=%s\\n' "$uptime_seconds"
    printf 'kernel_release=%s\\n' "$kernel_release"
    printf 'load1=%s\\n' "$load1"
    printf 'load5=%s\\n' "$load5"
    printf 'load15=%s\\n' "$load15"
    printf 'cpu_usage_percent=%s\\n' "$cpu_usage_percent"
    printf 'memory_used_bytes=%s\\n' "$memory_used_bytes"
    printf 'memory_total_bytes=%s\\n' "$memory_total_bytes"
    printf 'root_used_bytes=%s\\n' "$root_used_bytes"
    printf 'root_total_bytes=%s\\n' "$root_total_bytes"
    """

    private let sshRunner: any SSHRunning
    private let parser: TelemetryParser
    private let timeoutSeconds: TimeInterval

    public init(
        sshRunner: any SSHRunning = SSHClient(),
        parser: TelemetryParser = TelemetryParser(),
        timeoutSeconds: TimeInterval = 5
    ) {
        self.sshRunner = sshRunner
        self.parser = parser
        self.timeoutSeconds = timeoutSeconds
    }

    public func collect(for host: HostConfig) async throws -> HostTelemetry {
        let result = try await sshRunner.run(
            host: host.sshTarget,
            script: Self.remoteScript,
            timeoutSeconds: timeoutSeconds
        )

        guard result.exitCode == 0 else {
            throw TelemetryCollectionError.sshFailed(
                exitCode: result.exitCode,
                message: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        do {
            return try parser.parse(
                result.stdout,
                collectedAt: Date(),
                latency: result.elapsedSeconds
            )
        } catch {
            throw TelemetryCollectionError.parserFailed(error.localizedDescription)
        }
    }
}
