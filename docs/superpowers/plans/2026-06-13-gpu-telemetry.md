# GPU Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add RTX 5090 GPU telemetry to the existing native macOS menu bar app using the selected dedicated GPU panel layout.

**Architecture:** Extend `HostTelemetry` with a focused `GPUTelemetry` value model, parse optional `gpu=` lines alongside the current key-value system telemetry, and collect GPU fields with `nvidia-smi --query-gpu`. Keep no-GPU hosts valid by allowing zero GPU lines. Render GPU data as a dedicated subpanel inside each host card and mirror it in mock mode for UI review.

**Tech Stack:** Swift 6, SwiftPM, XCTest, SwiftUI `MenuBarExtra`, `/usr/bin/ssh`, `nvidia-smi --query-gpu`.

---

## File Structure

- Create `Sources/RemoteInfoCore/Models/GPUTelemetry.swift`: GPU telemetry value model and computed percentages.
- Modify `Sources/RemoteInfoCore/Models/HostTelemetry.swift`: add `gpus: [GPUTelemetry]` with a default empty value.
- Modify `Sources/RemoteInfoCore/Services/TelemetryParser.swift`: parse optional `gpu=` lines, allow multiple GPUs, reject malformed GPU numeric fields.
- Modify `Sources/RemoteInfoCore/Services/TelemetryCollector.swift`: add `nvidia-smi --query-gpu` collection and print `gpu=` lines when available.
- Modify `Sources/RemoteInfoCore/Services/MockTelemetryCollector.swift`: add one RTX 5090 per mock host with changing values.
- Modify `Sources/RemoteInfoApp/Views/HostCardView.swift`: add dedicated GPU panel below system metrics.
- Modify `Sources/RemoteInfoCore/Support/Formatters.swift`: add MiB and watts/temperature/clock formatting helpers where needed.
- Modify tests under `Tests/RemoteInfoCoreTests/`: parser, collector, mock collector, and fixture updates.
- Modify `README.md`: document GPU telemetry source.

---

### Task 1: GPU Telemetry Model

**Files:**
- Create: `Sources/RemoteInfoCore/Models/GPUTelemetry.swift`
- Modify: `Sources/RemoteInfoCore/Models/HostTelemetry.swift`
- Test: `Tests/RemoteInfoCoreTests/TelemetryParserTests.swift`

- [ ] **Step 1: Write the failing model expectation through parser tests**

Add assertions to `testParsesCompleteOutput` after existing root disk assertions:

```swift
XCTAssertEqual(telemetry.gpus.count, 1)
XCTAssertEqual(telemetry.gpus[0].index, 0)
XCTAssertEqual(telemetry.gpus[0].name, "NVIDIA GeForce RTX 5090")
XCTAssertEqual(telemetry.gpus[0].driverVersion, "575.64")
XCTAssertEqual(telemetry.gpus[0].utilizationPercent, 88)
XCTAssertEqual(telemetry.gpus[0].memoryUsedMiB, 29_800)
XCTAssertEqual(telemetry.gpus[0].memoryTotalMiB, 32_768)
XCTAssertEqual(telemetry.gpus[0].temperatureCelsius, 72)
XCTAssertEqual(telemetry.gpus[0].powerDrawWatts, 512)
XCTAssertEqual(telemetry.gpus[0].powerLimitWatts, 575)
XCTAssertEqual(telemetry.gpus[0].fanSpeedPercent, 64)
XCTAssertEqual(telemetry.gpus[0].graphicsClockMHz, 2_620)
```

Add this line to `completeOutput`:

```text
gpu=0|NVIDIA GeForce RTX 5090|575.64|88|29800|32768|72|512|575|64|2620
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryParserTests/testParsesCompleteOutput
```

Expected: compile failure because `HostTelemetry.gpus` and `GPUTelemetry` do not exist.

- [ ] **Step 3: Add the minimal model**

Create `GPUTelemetry` with:

```swift
public struct GPUTelemetry: Equatable, Sendable {
    public let index: Int
    public let name: String
    public let driverVersion: String
    public let utilizationPercent: Double
    public let memoryUsedMiB: Int64
    public let memoryTotalMiB: Int64
    public let temperatureCelsius: Double
    public let powerDrawWatts: Double
    public let powerLimitWatts: Double
    public let fanSpeedPercent: Double
    public let graphicsClockMHz: Int

    public var memoryUsagePercent: Double {
        guard memoryTotalMiB > 0 else { return 0 }
        return Double(memoryUsedMiB) / Double(memoryTotalMiB) * 100
    }

    public var powerUsagePercent: Double {
        guard powerLimitWatts > 0 else { return 0 }
        return powerDrawWatts / powerLimitWatts * 100
    }
}
```

Add `public let gpus: [GPUTelemetry]` to `HostTelemetry` and a default initializer parameter `gpus: [GPUTelemetry] = []`.

- [ ] **Step 4: Run the focused test**

Expected: still fails until parser creates `GPUTelemetry`.

---

### Task 2: Parser Support For GPU Lines

**Files:**
- Modify: `Sources/RemoteInfoCore/Services/TelemetryParser.swift`
- Test: `Tests/RemoteInfoCoreTests/TelemetryParserTests.swift`

- [ ] **Step 1: Add parser edge-case tests**

Add:

```swift
func testAllowsOutputWithoutGPULines() throws {
    let telemetry = try TelemetryParser().parse(
        systemOnlyOutput,
        collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
        latency: 0.2
    )

    XCTAssertEqual(telemetry.gpus, [])
}

func testReportsMalformedGPUValues() {
    let output = completeOutput.replacingOccurrences(of: "|88|", with: "|not-a-number|")

    XCTAssertThrowsError(
        try TelemetryParser().parse(
            output,
            collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
            latency: 0.2
        )
    ) { error in
        XCTAssertEqual(
            error as? TelemetryParseError,
            .invalidNumber(key: "gpu.utilization_percent", value: "not-a-number")
        )
    }
}
```

Add `systemOnlyOutput` equal to the previous `completeOutput` without `gpu=`.

- [ ] **Step 2: Run parser tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryParserTests
```

Expected: failures because parser still treats duplicate `gpu` lines as duplicate keys or ignores GPU data.

- [ ] **Step 3: Implement GPU parsing**

Change internal parsing to return both scalar values and `[String]` GPU payloads. Allow duplicate `gpu` keys by appending their values. Parse each GPU payload as exactly 11 pipe-separated fields in this order:

```text
index|name|driver|utilization|memory_used_mib|memory_total_mib|temperature_c|power_draw_w|power_limit_w|fan_percent|graphics_clock_mhz
```

- [ ] **Step 4: Run parser tests**

Expected: all `TelemetryParserTests` pass.

---

### Task 3: Remote Script Collection

**Files:**
- Modify: `Sources/RemoteInfoCore/Services/TelemetryCollector.swift`
- Test: `Tests/RemoteInfoCoreTests/TelemetryCollectorTests.swift`

- [ ] **Step 1: Add collector script assertions**

In `testCollectsTelemetryFromSuccessfulSSHResult`, assert:

```swift
XCTAssertTrue(script.contains("nvidia-smi"))
XCTAssertTrue(script.contains("--query-gpu=index,name,driver_version,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed,clocks.current.graphics"))
```

Add the same `gpu=` line used by parser tests to `completeTelemetryOutput`.

- [ ] **Step 2: Run collector tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TelemetryCollectorTests
```

Expected: script assertion fails until `nvidia-smi` is added.

- [ ] **Step 3: Add `nvidia-smi` output**

In `TelemetryCollector.remoteScript`, after system fields are printed, add a guarded command:

```sh
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=index,name,driver_version,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed,clocks.current.graphics --format=csv,noheader,nounits |
  awk -F ', ' 'NF == 11 {
    printf "gpu=%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
  }'
fi
```

- [ ] **Step 4: Run collector tests**

Expected: all collector tests pass.

---

### Task 4: Mock GPU Data

**Files:**
- Modify: `Sources/RemoteInfoCore/Services/MockTelemetryCollector.swift`
- Test: `Tests/RemoteInfoCoreTests/MockTelemetryCollectorTests.swift`

- [ ] **Step 1: Add mock GPU tests**

Add to `testCollectsTelemetryForMockHost`:

```swift
XCTAssertEqual(telemetry.gpus.count, 1)
XCTAssertEqual(telemetry.gpus[0].name, "NVIDIA GeForce RTX 5090")
XCTAssertEqual(telemetry.gpus[0].memoryTotalMiB, 32_768)
XCTAssertGreaterThan(telemetry.gpus[0].utilizationPercent, 0)
```

Add to `testTelemetryChangesAcrossCollections`:

```swift
XCTAssertNotEqual(first.gpus[0].utilizationPercent, second.gpus[0].utilizationPercent)
XCTAssertNotEqual(first.gpus[0].memoryUsedMiB, second.gpus[0].memoryUsedMiB)
```

- [ ] **Step 2: Run mock tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MockTelemetryCollectorTests
```

Expected: GPU assertions fail until mock returns GPU values.

- [ ] **Step 3: Add mock RTX 5090 telemetry**

Create one `GPUTelemetry` per mock collection with changing utilization, memory, temperature, power, fan and clock values. Use `memoryTotalMiB: 32_768`.

- [ ] **Step 4: Run mock tests**

Expected: all mock tests pass.

---

### Task 5: Dedicated GPU Panel UI

**Files:**
- Modify: `Sources/RemoteInfoApp/Views/HostCardView.swift`
- Modify: `Sources/RemoteInfoCore/Support/Formatters.swift`
- Test: build and mock launch

- [ ] **Step 1: Add formatting helpers**

Add functions:

```swift
public static func mebibytesAsGibibytes(_ value: Int64) -> String
public static func watts(_ value: Double) -> String
public static func celsius(_ value: Double) -> String
public static func megahertzAsGigahertz(_ value: Int) -> String
```

- [ ] **Step 2: Render GPU panel**

In `HostCardView.metrics(for:)`, after the existing `Grid`, render:

```swift
ForEach(telemetry.gpus) { gpu in
    gpuPanel(for: gpu)
}
```

Make `GPUTelemetry` identifiable by `index`, and build a compact panel matching design B: header with name/index/driver/temp, bars for util and VRAM, stats for power/fan/clock.

- [ ] **Step 3: Build and launch mock mode**

Run:

```bash
swift build
./script/build_and_run.sh --mock
```

Expected: app launches with mock GPU panels.

---

### Task 6: Final Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document GPU source**

Add a short note that GPU telemetry uses `nvidia-smi --query-gpu` when available and mock mode includes RTX 5090 GPU data.

- [ ] **Step 2: Run full verification**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
swift build
./script/build_and_run.sh --verify
./script/build_and_run.sh --mock
./script/check_no_secrets.sh
```

Expected: all commands pass. Stop the app process after launch checks.

- [ ] **Step 3: Commit and push**

Run:

```bash
git add README.md Sources Tests
git commit -m "Add GPU telemetry panel"
git push origin main
```
