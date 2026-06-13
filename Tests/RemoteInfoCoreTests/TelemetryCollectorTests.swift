@testable import RemoteInfoCore
import XCTest

final class TelemetryCollectorTests: XCTestCase {
    func testCollectsTelemetryFromSuccessfulSSHResult() async throws {
        let runner = FakeSSHRunner(
            result: SSHResult(
                stdout: completeTelemetryOutput,
                stderr: "",
                exitCode: 0,
                elapsedSeconds: 0.25
            )
        ) { host, script, timeoutSeconds in
            XCTAssertEqual(host, "remote-info-host-a")
            XCTAssertTrue(script.contains("/proc/stat"))
            XCTAssertTrue(script.contains("uname -r"))
            XCTAssertTrue(script.contains("nvidia-smi"))
            XCTAssertTrue(script.contains("ps -eo pid=,comm=,pcpu=,pmem= --sort=-pcpu"))
            XCTAssertTrue(script.contains("/proc/net/dev"))
            XCTAssertTrue(script.contains("-F ':'"))
            XCTAssertTrue(script.contains("gsub(/^[[:space:]]+|[[:space:]]+$/, \"\", interface_name)"))
            XCTAssertTrue(script.contains("ip route get 1.1.1.1"))
            XCTAssertTrue(
                script.contains(
                    "--query-gpu=index,name,driver_version,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed,clocks.current.graphics"
                )
            )
            XCTAssertEqual(timeoutSeconds, 20)
        }
        let collector = TelemetryCollector(sshRunner: runner)

        let telemetry = try await collector.collect(for: host)

        XCTAssertEqual(telemetry.cpuUsagePercent, 18.2)
        XCTAssertEqual(telemetry.kernelRelease, "6.8.0-test")
        XCTAssertEqual(telemetry.gpus.count, 1)
        XCTAssertEqual(telemetry.gpus[0].name, "NVIDIA GeForce RTX 5090")
        XCTAssertEqual(telemetry.topProcesses.count, 1)
        XCTAssertEqual(telemetry.topProcesses[0].command, "python3")
        XCTAssertEqual(telemetry.network?.interfaceName, "eth0")
        XCTAssertEqual(telemetry.latencySeconds, 0.25)
    }

    func testRemoteScriptPrintsBufferedNetworkLineWithLineTerminator() {
        XCTAssertTrue(TelemetryCollector.remoteScript.contains("printf '%s\\n' \"$network_line\""))
    }

    func testReportsSSHFailure() async throws {
        let runner = FakeSSHRunner(
            result: SSHResult(
                stdout: "",
                stderr: "Permission denied",
                exitCode: 255,
                elapsedSeconds: 0.1
            )
        )
        let collector = TelemetryCollector(sshRunner: runner)

        do {
            _ = try await collector.collect(for: host)
            XCTFail("Expected collect to throw")
        } catch {
            XCTAssertEqual(
                error as? TelemetryCollectionError,
                .sshFailed(exitCode: 255, message: "Permission denied")
            )
        }
    }

    func testSSHFailureDescriptionsAreActionable() {
        XCTAssertEqual(
            TelemetryCollectionError
                .sshFailed(exitCode: 255, message: "Permission denied (publickey).")
                .localizedDescription,
            "SSH authentication failed. Check your SSH key, ssh-agent, and BatchMode access."
        )
        XCTAssertEqual(
            TelemetryCollectionError
                .sshFailed(exitCode: 255, message: "Could not resolve hostname host-a: nodename nor servname provided")
                .localizedDescription,
            "SSH host could not be resolved. Check the host alias in ~/.ssh/config."
        )
        XCTAssertEqual(
            TelemetryCollectionError
                .sshFailed(exitCode: 255, message: "Operation timed out")
                .localizedDescription,
            "SSH connection timed out. Check network reachability, firewall rules, or VPN state."
        )
        XCTAssertEqual(
            TelemetryCollectionError
                .sshFailed(exitCode: 255, message: "Connection refused")
                .localizedDescription,
            "SSH connection was refused. Check that sshd is running and reachable on the target."
        )
    }

    private let host = HostConfig(
        id: "host-a",
        name: "Host A",
        sshTarget: "remote-info-host-a"
    )

    private let completeTelemetryOutput = """
    uptime_seconds=123456
    kernel_release=6.8.0-test
    load1=0.42
    load5=0.38
    load15=0.31
    cpu_usage_percent=18.2
    memory_used_bytes=4412346368
    memory_total_bytes=10307921510
    root_used_bytes=77309411328
    root_total_bytes=107374182400
    gpu=0|NVIDIA GeForce RTX 5090|575.64|88|29800|32768|72|512|575|64|2620
    process=2411|python3|216.4|12.1
    network=eth0|up|18398656|3355443|0|0|0|0
    """
}

private struct FakeSSHRunner: SSHRunning {
    let result: SSHResult
    var onRun: @Sendable (String, String, TimeInterval) -> Void = { _, _, _ in }

    func run(host: String, script: String, timeoutSeconds: TimeInterval) async throws -> SSHResult {
        onRun(host, script, timeoutSeconds)
        return result
    }
}
