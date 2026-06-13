# Activity Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add compact CPU process and network status telemetry to the native macOS menu bar panel.

**Architecture:** Extend `HostTelemetry` with optional activity data while keeping base telemetry required. The SSH script emits optional `process=` and `network=` records, the parser accepts missing activity rows, mock mode generates reviewable activity values, and SwiftUI renders one compact section between basic metrics and GPU details.

**Tech Stack:** Swift Package Manager, Swift, XCTest, SwiftUI, Linux `/proc`, `ps`, `ip route`.

---

### Task 1: Models and Parser

**Files:**
- Create: `Sources/RemoteInfoCore/Models/ProcessTelemetry.swift`
- Create: `Sources/RemoteInfoCore/Models/NetworkTelemetry.swift`
- Modify: `Sources/RemoteInfoCore/Models/HostTelemetry.swift`
- Modify: `Sources/RemoteInfoCore/Services/TelemetryParser.swift`
- Test: `Tests/RemoteInfoCoreTests/TelemetryParserTests.swift`

- [ ] **Step 1: Write failing parser tests**

Add activity rows to `completeOutput` and assert parsed values in `testParsesCompleteOutput`:

```swift
XCTAssertEqual(telemetry.topProcesses.count, 2)
XCTAssertEqual(telemetry.topProcesses[0].pid, 2411)
XCTAssertEqual(telemetry.topProcesses[0].command, "python3")
XCTAssertEqual(telemetry.topProcesses[0].cpuPercent, 216.4)
XCTAssertEqual(telemetry.topProcesses[0].memoryPercent, 12.1)

let network = try XCTUnwrap(telemetry.network)
XCTAssertEqual(network.interfaceName, "eth0")
XCTAssertEqual(network.operstate, "up")
XCTAssertEqual(network.receiveBytesPerSecond, 18_398_656)
XCTAssertEqual(network.transmitBytesPerSecond, 3_355_443)
XCTAssertEqual(network.errorCount, 0)
XCTAssertEqual(network.dropCount, 0)
```

Add separate malformed activity tests:

```swift
func testReportsMalformedProcessValues() { ... .invalidNumber(key: "process.cpu_percent", value: "bad") }
func testReportsMalformedNetworkValues() { ... .invalidNumber(key: "network.receive_bytes_per_second", value: "bad") }
```

- [ ] **Step 2: Verify parser tests fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryParserTests
```

Expected: compile failure or test failure because `topProcesses`, `network`, `ProcessTelemetry`, and `NetworkTelemetry` do not exist yet.

- [ ] **Step 3: Implement models and parser**

Create `ProcessTelemetry` with `pid`, `command`, `cpuPercent`, and `memoryPercent`.

Create `NetworkTelemetry` with `interfaceName`, `operstate`, receive/transmit byte rates, receive/transmit errors, and receive/transmit drops. Add computed `errorCount` and `dropCount`.

Extend parser output to collect repeatable `process=` rows and optional single `network=` row. Parse the agreed pipe-delimited formats and keep missing activity data non-fatal.

- [ ] **Step 4: Verify parser tests pass**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryParserTests
```

Expected: `TelemetryParserTests` passes.

### Task 2: Collector and Mock Data

**Files:**
- Modify: `Sources/RemoteInfoCore/Services/TelemetryCollector.swift`
- Modify: `Sources/RemoteInfoCore/Services/MockTelemetryCollector.swift`
- Test: `Tests/RemoteInfoCoreTests/TelemetryCollectorTests.swift`
- Test: `Tests/RemoteInfoCoreTests/MockTelemetryCollectorTests.swift`

- [ ] **Step 1: Write failing collector and mock tests**

Update collector tests to assert the remote script contains `ps -eo`, `/proc/net/dev`, and `ip route get`.

Update mock tests to assert `topProcesses` is non-empty, `network` is present, and at least one activity value changes across collections.

- [ ] **Step 2: Verify tests fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryCollectorTests --filter MockTelemetryCollectorTests
```

Expected: compile failure or test failure because activity data is not emitted yet.

- [ ] **Step 3: Implement collector and mock activity output**

Add shell helpers to `TelemetryCollector.remoteScript`:

- Determine the default interface with `ip route get 1.1.1.1`.
- Fall back to the first non-loopback interface from `/sys/class/net`.
- Read `/proc/net/dev` before and after the existing one-second sleep.
- Emit one `network=` line when interface counters are available.
- Emit up to three `process=` lines from `ps -eo pid=,comm=,pcpu=,pmem= --sort=-pcpu`.

Update `MockTelemetryCollector` to return two or three process rows and one network row per host.

- [ ] **Step 4: Verify collector and mock tests pass**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryCollectorTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MockTelemetryCollectorTests
```

Expected: both filtered test suites pass.

### Task 3: UI and Formatting

**Files:**
- Modify: `Sources/RemoteInfoCore/Support/Formatters.swift`
- Modify: `Sources/RemoteInfoApp/Views/HostCardView.swift`
- Test: `Tests/RemoteInfoCoreTests/TelemetryParserTests.swift`

- [ ] **Step 1: Write failing formatter test**

Add:

```swift
func testRateFormatter() {
    XCTAssertEqual(RemoteInfoFormatters.bytesPerSecond(18_398_656), "17.5 MB/s")
}
```

- [ ] **Step 2: Verify formatter test fails**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryParserTests/testRateFormatter
```

Expected: compile failure because `bytesPerSecond` does not exist.

- [ ] **Step 3: Implement formatter and activity section**

Add `RemoteInfoFormatters.bytesPerSecond(_:)`, using the existing binary `ByteCountFormatter` behavior plus `/s`.

Add an `Activity` section to `HostCardView` below the basic metrics grid. Render network only when present and render CPU top-process chips only when available. Keep the section compact and line-limited.

- [ ] **Step 4: Verify formatter test passes**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryParserTests/testRateFormatter
```

Expected: formatter test passes.

### Task 4: Documentation, Verification, Commit, Push

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README**

Document that process telemetry uses short command names only and network telemetry reads default interface counters from the remote host.

- [ ] **Step 2: Run full verification**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
swift build
./script/build_and_run.sh --verify
./script/build_and_run.sh --mock
```

Expected: all commands exit 0.

- [ ] **Step 3: Run secret scan**

Run:

```bash
git add docs/superpowers/specs/2026-06-13-activity-telemetry-design.md docs/superpowers/plans/2026-06-13-activity-telemetry.md Sources Tests README.md
./script/check_no_secrets.sh
```

Expected: no output and exit 0.

- [ ] **Step 4: Commit and push**

Run:

```bash
git commit -m "Add activity telemetry"
git push origin main
```

Expected: push succeeds with no sensitive host or key material committed.
