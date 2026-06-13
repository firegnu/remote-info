# Remote Info Native App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native Swift/SwiftUI macOS menu bar app that shows live SSH-collected telemetry for two Linux hosts without committing secrets.

**Architecture:** Use Swift Package Manager with a native SwiftUI executable staged into a `.app` bundle by `script/build_and_run.sh`. Keep non-UI logic in `RemoteInfoCore` for unit testing, and keep the app target focused on `MenuBarExtra` and SwiftUI views. Real host configuration is loaded from `~/.config/remote-info/hosts.json`; the repository only contains a safe example config.

**Tech Stack:** Swift 6, SwiftUI, AppKit-backed `.app` bundle, Swift Package Manager, XCTest, `/usr/bin/ssh`.

---

## File Structure

- Create `Package.swift`: SwiftPM package with `RemoteInfoCore`, `RemoteInfoApp`, and `RemoteInfoCoreTests`.
- Create `Sources/RemoteInfoCore/Models/HostConfig.swift`: host config model and validation.
- Create `Sources/RemoteInfoCore/Models/HostTelemetry.swift`: structured telemetry snapshot.
- Create `Sources/RemoteInfoCore/Models/TelemetryStatus.swift`: loading, online, stale, offline, and error state.
- Create `Sources/RemoteInfoCore/Services/HostConfigLoader.swift`: load `~/.config/remote-info/hosts.json` or a test-supplied path.
- Create `Sources/RemoteInfoCore/Services/SSHClient.swift`: run `/usr/bin/ssh` with batch mode and timeout.
- Create `Sources/RemoteInfoCore/Services/TelemetryCollector.swift`: execute the remote read-only script and convert SSH results.
- Create `Sources/RemoteInfoCore/Services/TelemetryParser.swift`: parse key/value telemetry output.
- Create `Sources/RemoteInfoCore/Stores/TelemetryStore.swift`: refresh orchestration and state ownership.
- Create `Sources/RemoteInfoCore/Support/Formatters.swift`: display formatting helpers.
- Create `Sources/RemoteInfoApp/App/RemoteInfoApp.swift`: native SwiftUI `MenuBarExtra` entry point.
- Create `Sources/RemoteInfoApp/Views/MenuBarPanelView.swift`: panel composition.
- Create `Sources/RemoteInfoApp/Views/FleetSummaryView.swift`: top summary.
- Create `Sources/RemoteInfoApp/Views/HostCardView.swift`: per-host card.
- Create `Sources/RemoteInfoApp/Views/MetricView.swift`: compact metric cell.
- Create `Tests/RemoteInfoCoreTests/HostConfigLoaderTests.swift`: config loading tests.
- Create `Tests/RemoteInfoCoreTests/TelemetryParserTests.swift`: parser tests.
- Create `Tests/RemoteInfoCoreTests/TelemetryStoreTests.swift`: refresh behavior tests using a fake collector.
- Create `config/hosts.example.json`: safe sample config with generic aliases only.
- Modify `.gitignore`: ignore `.build/`, `dist/`, `.DS_Store`, and `config/hosts.local.json`.
- Create `script/check_no_secrets.sh`: staged-file secret marker scan.
- Create `script/build_and_run.sh`: build, bundle, launch, and verify the native app.
- Create `.codex/environments/environment.toml`: Codex Run action pointing to `./script/build_and_run.sh`.
- Create `README.md`: setup, local config path, build/run, and security notes.

## Task 1: Bootstrap Native Swift Package And Run Loop

**Files:**
- Create: `Package.swift`
- Create: `Sources/RemoteInfoCore/Support/RemoteInfoCore.swift`
- Create: `Sources/RemoteInfoApp/App/RemoteInfoApp.swift`
- Create: `Sources/RemoteInfoApp/Views/MenuBarPanelView.swift`
- Create: `script/build_and_run.sh`
- Create: `script/check_no_secrets.sh`
- Create: `.codex/environments/environment.toml`
- Modify: `.gitignore`

- [ ] **Step 1: Write the package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemoteInfo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RemoteInfo", targets: ["RemoteInfoApp"])
    ],
    targets: [
        .target(
            name: "RemoteInfoCore"
        ),
        .executableTarget(
            name: "RemoteInfoApp",
            dependencies: ["RemoteInfoCore"]
        ),
        .testTarget(
            name: "RemoteInfoCoreTests",
            dependencies: ["RemoteInfoCore"]
        )
    ]
)
```

- [ ] **Step 2: Add minimal core target file**

Create `Sources/RemoteInfoCore/Support/RemoteInfoCore.swift`:

```swift
import Foundation

public enum RemoteInfoCore {
    public static let appName = "RemoteInfo"
    public static let bundleIdentifier = "dev.firegnu.RemoteInfo"
}
```

- [ ] **Step 3: Add minimal native SwiftUI app entry**

Create `Sources/RemoteInfoApp/App/RemoteInfoApp.swift`:

```swift
import RemoteInfoCore
import SwiftUI

@main
struct RemoteInfoApp: App {
    var body: some Scene {
        MenuBarExtra("Remote Info", systemImage: "server.rack") {
            MenuBarPanelView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 4: Add temporary panel view**

Create `Sources/RemoteInfoApp/Views/MenuBarPanelView.swift`:

```swift
import SwiftUI

struct MenuBarPanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote Info")
                .font(.headline)
            Text("Native macOS menu bar app")
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
```

- [ ] **Step 5: Add build and run script**

Create `script/build_and_run.sh` and make it executable with `chmod +x script/build_and_run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="RemoteInfo"
BUNDLE_ID="dev.firegnu.RemoteInfo"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 6: Add staged secret marker scan**

Create `script/check_no_secrets.sh` and make it executable with `chmod +x script/check_no_secrets.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

staged_files="$(git diff --cached --name-only --diff-filter=ACM | grep -Ev '(^script/check_no_secrets.sh$|^docs/superpowers/plans/)' || true)"

if [[ -z "$staged_files" ]]; then
  exit 0
fi

if printf '%s\n' "$staged_files" | xargs rg -n --pcre2 -- \
  '-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}|IdentityFile\s+~?/' ; then
  echo "Potential secret found in staged files. Remove it before committing." >&2
  exit 1
fi
```

- [ ] **Step 7: Add Codex Run action**

Create `.codex/environments/environment.toml`:

```toml
# THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY
version = 1
name = "remote-info"

[setup]
script = ""

[[actions]]
name = "Run"
icon = "run"
command = "./script/build_and_run.sh"
```

- [ ] **Step 8: Expand gitignore**

Update `.gitignore`:

```gitignore
.superpowers/
.build/
dist/
.DS_Store
config/hosts.local.json
```

- [ ] **Step 9: Build and verify minimal app**

Run:

```bash
swift build
./script/build_and_run.sh --verify
```

Expected: `swift build` succeeds. `--verify` exits with status 0 and `RemoteInfo` appears as a menu bar item, not a Dock app.

- [ ] **Step 10: Commit bootstrap**

Run:

```bash
git status --short
git add Package.swift Sources/RemoteInfoCore Sources/RemoteInfoApp script/build_and_run.sh script/check_no_secrets.sh .codex/environments/environment.toml .gitignore
./script/check_no_secrets.sh
git commit -m "Bootstrap native macOS menu bar app"
```

## Task 2: Add Safe Host Configuration

**Files:**
- Create: `config/hosts.example.json`
- Create: `Sources/RemoteInfoCore/Models/HostConfig.swift`
- Create: `Sources/RemoteInfoCore/Services/HostConfigLoader.swift`
- Create: `Tests/RemoteInfoCoreTests/HostConfigLoaderTests.swift`
- Create: `README.md`

- [ ] **Step 1: Add safe example host config**

Create `config/hosts.example.json`:

```json
{
  "hosts": [
    {
      "id": "host-a",
      "name": "Host A",
      "sshTarget": "remote-info-host-a"
    },
    {
      "id": "host-b",
      "name": "Host B",
      "sshTarget": "remote-info-host-b"
    }
  ]
}
```

- [ ] **Step 2: Write failing host config tests**

Create `Tests/RemoteInfoCoreTests/HostConfigLoaderTests.swift`:

```swift
import Foundation
import Testing
@testable import RemoteInfoCore

@Suite("HostConfigLoader")
struct HostConfigLoaderTests {
    @Test
    func loadsTwoHostsFromJSON() throws {
        let url = try writeConfig("""
        {
          "hosts": [
            { "id": "host-a", "name": "Host A", "sshTarget": "remote-info-host-a" },
            { "id": "host-b", "name": "Host B", "sshTarget": "remote-info-host-b" }
          ]
        }
        """)

        let hosts = try HostConfigLoader().load(from: url)

        #expect(hosts == [
            HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"),
            HostConfig(id: "host-b", name: "Host B", sshTarget: "remote-info-host-b")
        ])
    }

    @Test
    func rejectsConfigsThatDoNotContainExactlyTwoHosts() throws {
        let url = try writeConfig("""
        {
          "hosts": [
            { "id": "host-a", "name": "Host A", "sshTarget": "remote-info-host-a" }
          ]
        }
        """)

        do {
            _ = try HostConfigLoader().load(from: url)
            Issue.record("Expected HostConfigError.expectedExactlyTwoHosts")
        } catch let error as HostConfigError {
            #expect(error == .expectedExactlyTwoHosts(actualCount: 1))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func rejectsEmptySSHtarget() throws {
        let url = try writeConfig("""
        {
          "hosts": [
            { "id": "host-a", "name": "Host A", "sshTarget": "" },
            { "id": "host-b", "name": "Host B", "sshTarget": "remote-info-host-b" }
          ]
        }
        """)

        do {
            _ = try HostConfigLoader().load(from: url)
            Issue.record("Expected HostConfigError.emptyField")
        } catch let error as HostConfigError {
            #expect(error == .emptyField("sshTarget"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func writeConfig(_ contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("hosts.json")
        try contents.data(using: .utf8)!.write(to: url)
        return url
    }
}
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```bash
swift test --filter HostConfigLoaderTests
```

Expected: FAIL because `HostConfig`, `HostConfigLoader`, and `HostConfigError` do not exist.

- [ ] **Step 4: Implement host config model**

Create `Sources/RemoteInfoCore/Models/HostConfig.swift`:

```swift
import Foundation

public struct HostConfig: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let sshTarget: String

    public init(id: String, name: String, sshTarget: String) {
        self.id = id
        self.name = name
        self.sshTarget = sshTarget
    }
}

public struct HostConfigFile: Codable, Equatable, Sendable {
    public let hosts: [HostConfig]

    public init(hosts: [HostConfig]) {
        self.hosts = hosts
    }
}

public enum HostConfigError: Error, Equatable, LocalizedError {
    case fileMissing(URL)
    case expectedExactlyTwoHosts(actualCount: Int)
    case emptyField(String)

    public var errorDescription: String? {
        switch self {
        case .fileMissing(let url):
            return "Host config file was not found at \(url.path)."
        case .expectedExactlyTwoHosts(let actualCount):
            return "Expected exactly two hosts, found \(actualCount)."
        case .emptyField(let field):
            return "Host config contains an empty \(field)."
        }
    }
}
```

- [ ] **Step 5: Implement host config loader**

Create `Sources/RemoteInfoCore/Services/HostConfigLoader.swift`:

```swift
import Foundation

public struct HostConfigLoader: Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func defaultConfigURL() -> URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("remote-info", isDirectory: true)
            .appendingPathComponent("hosts.json")
    }

    public func loadDefault() throws -> [HostConfig] {
        try load(from: defaultConfigURL())
    }

    public func load(from url: URL) throws -> [HostConfig] {
        guard fileManager.fileExists(atPath: url.path) else {
            throw HostConfigError.fileMissing(url)
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(HostConfigFile.self, from: data)
        try validate(decoded.hosts)
        return decoded.hosts
    }

    private func validate(_ hosts: [HostConfig]) throws {
        guard hosts.count == 2 else {
            throw HostConfigError.expectedExactlyTwoHosts(actualCount: hosts.count)
        }

        for host in hosts {
            if host.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw HostConfigError.emptyField("id")
            }
            if host.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw HostConfigError.emptyField("name")
            }
            if host.sshTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw HostConfigError.emptyField("sshTarget")
            }
        }
    }
}
```

- [ ] **Step 6: Add README setup and security notes**

Create `README.md`:

```markdown
# Remote Info

Remote Info is a native SwiftUI macOS menu bar app for checking two Linux hosts through direct SSH telemetry collection.

## Host Config

Real host configuration is intentionally not committed. Create:

```bash
mkdir -p ~/.config/remote-info
cp config/hosts.example.json ~/.config/remote-info/hosts.json
```

Edit `~/.config/remote-info/hosts.json` so each `sshTarget` is an alias that already works with your local `ssh` command.

## Security

- Do not commit SSH keys, passwords, passphrases, tokens, real hostnames, or `IdentityFile` paths.
- The app uses `/usr/bin/ssh` with your existing SSH config and ssh-agent.
- The app does not store private keys or passwords.
```

- [ ] **Step 7: Run tests and secret scan**

Run:

```bash
swift test --filter HostConfigLoaderTests
git add config/hosts.example.json Sources/RemoteInfoCore/Models/HostConfig.swift Sources/RemoteInfoCore/Services/HostConfigLoader.swift Tests/RemoteInfoCoreTests/HostConfigLoaderTests.swift README.md
./script/check_no_secrets.sh
```

Expected: tests PASS and secret scan exits 0.

- [ ] **Step 8: Commit host config**

Run:

```bash
git commit -m "Add safe host configuration loading"
```

## Task 3: Add Telemetry Parser

**Files:**
- Create: `Sources/RemoteInfoCore/Models/HostTelemetry.swift`
- Create: `Sources/RemoteInfoCore/Services/TelemetryParser.swift`
- Create: `Sources/RemoteInfoCore/Support/Formatters.swift`
- Create: `Tests/RemoteInfoCoreTests/TelemetryParserTests.swift`

- [ ] **Step 1: Write failing parser tests**

Create `Tests/RemoteInfoCoreTests/TelemetryParserTests.swift`:

```swift
import Foundation
import Testing
@testable import RemoteInfoCore

@Suite("TelemetryParser")
struct TelemetryParserTests {
    @Test
    func parsesCompleteOutput() throws {
        let output = """
        uptime_seconds=123456
        load1=0.42
        load5=0.38
        load15=0.31
        cpu_usage_percent=18.2
        memory_used_bytes=4412346368
        memory_total_bytes=10307921510
        root_used_bytes=77309411328
        root_total_bytes=107374182400
        """

        let telemetry = try TelemetryParser().parse(output, collectedAt: Date(timeIntervalSince1970: 100), latency: 0.25)

        #expect(telemetry.uptimeSeconds == 123456)
        #expect(telemetry.load1 == 0.42)
        #expect(telemetry.cpuUsagePercent == 18.2)
        #expect(telemetry.memoryUsedBytes == 4_412_346_368)
        #expect(telemetry.memoryTotalBytes == 10_307_921_510)
        #expect(telemetry.rootUsedBytes == 77_309_411_328)
        #expect(telemetry.rootTotalBytes == 107_374_182_400)
        #expect(telemetry.latencySeconds == 0.25)
    }

    @Test
    func ignoresUnknownKeys() throws {
        let output = """
        uptime_seconds=10
        load1=1
        load5=1
        load15=1
        cpu_usage_percent=2
        memory_used_bytes=3
        memory_total_bytes=4
        root_used_bytes=5
        root_total_bytes=6
        extra_key=ignored
        """

        let telemetry = try TelemetryParser().parse(output, collectedAt: Date(), latency: 0.1)

        #expect(telemetry.rootTotalBytes == 6)
    }

    @Test
    func reportsMissingRequiredKey() {
        let output = """
        uptime_seconds=10
        load1=1
        load5=1
        load15=1
        cpu_usage_percent=2
        memory_used_bytes=3
        memory_total_bytes=4
        root_used_bytes=5
        """

        do {
            _ = try TelemetryParser().parse(output, collectedAt: Date(), latency: 0.1)
            Issue.record("Expected TelemetryParseError.missingKey")
        } catch let error as TelemetryParseError {
            #expect(error == .missingKey("root_total_bytes"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func reportsMalformedNumbers() {
        let output = """
        uptime_seconds=10
        load1=not-a-number
        load5=1
        load15=1
        cpu_usage_percent=2
        memory_used_bytes=3
        memory_total_bytes=4
        root_used_bytes=5
        root_total_bytes=6
        """

        do {
            _ = try TelemetryParser().parse(output, collectedAt: Date(), latency: 0.1)
            Issue.record("Expected TelemetryParseError.invalidNumber")
        } catch let error as TelemetryParseError {
            #expect(error == .invalidNumber(key: "load1", value: "not-a-number"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run parser tests to verify failure**

Run:

```bash
swift test --filter TelemetryParserTests
```

Expected: FAIL because parser and telemetry types do not exist.

- [ ] **Step 3: Implement telemetry model**

Create `Sources/RemoteInfoCore/Models/HostTelemetry.swift`:

```swift
import Foundation

public struct HostTelemetry: Equatable, Sendable {
    public let collectedAt: Date
    public let latencySeconds: TimeInterval
    public let uptimeSeconds: Int
    public let load1: Double
    public let load5: Double
    public let load15: Double
    public let cpuUsagePercent: Double
    public let memoryUsedBytes: Int64
    public let memoryTotalBytes: Int64
    public let rootUsedBytes: Int64
    public let rootTotalBytes: Int64

    public init(
        collectedAt: Date,
        latencySeconds: TimeInterval,
        uptimeSeconds: Int,
        load1: Double,
        load5: Double,
        load15: Double,
        cpuUsagePercent: Double,
        memoryUsedBytes: Int64,
        memoryTotalBytes: Int64,
        rootUsedBytes: Int64,
        rootTotalBytes: Int64
    ) {
        self.collectedAt = collectedAt
        self.latencySeconds = latencySeconds
        self.uptimeSeconds = uptimeSeconds
        self.load1 = load1
        self.load5 = load5
        self.load15 = load15
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.rootUsedBytes = rootUsedBytes
        self.rootTotalBytes = rootTotalBytes
    }

    public var memoryUsagePercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return Double(memoryUsedBytes) / Double(memoryTotalBytes) * 100
    }

    public var rootUsagePercent: Double {
        guard rootTotalBytes > 0 else { return 0 }
        return Double(rootUsedBytes) / Double(rootTotalBytes) * 100
    }
}
```

- [ ] **Step 4: Implement telemetry parser**

Create `Sources/RemoteInfoCore/Services/TelemetryParser.swift`:

```swift
import Foundation

public enum TelemetryParseError: Error, Equatable, LocalizedError {
    case missingKey(String)
    case invalidLine(String)
    case invalidNumber(key: String, value: String)

    public var errorDescription: String? {
        switch self {
        case .missingKey(let key):
            return "Telemetry output is missing \(key)."
        case .invalidLine(let line):
            return "Telemetry output contains an invalid line: \(line)."
        case .invalidNumber(let key, let value):
            return "Telemetry value for \(key) is not numeric: \(value)."
        }
    }
}

public struct TelemetryParser: Sendable {
    public init() {}

    public func parse(_ output: String, collectedAt: Date, latency: TimeInterval) throws -> HostTelemetry {
        let values = try keyValues(from: output)

        return HostTelemetry(
            collectedAt: collectedAt,
            latencySeconds: latency,
            uptimeSeconds: try int("uptime_seconds", values),
            load1: try double("load1", values),
            load5: try double("load5", values),
            load15: try double("load15", values),
            cpuUsagePercent: try double("cpu_usage_percent", values),
            memoryUsedBytes: try int64("memory_used_bytes", values),
            memoryTotalBytes: try int64("memory_total_bytes", values),
            rootUsedBytes: try int64("root_used_bytes", values),
            rootTotalBytes: try int64("root_total_bytes", values)
        )
    }

    private func keyValues(from output: String) throws -> [String: String] {
        var result: [String: String] = [:]

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard let separator = line.firstIndex(of: "=") else {
                throw TelemetryParseError.invalidLine(line)
            }

            let key = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
            result[key] = value
        }

        return result
    }

    private func required(_ key: String, _ values: [String: String]) throws -> String {
        guard let value = values[key] else {
            throw TelemetryParseError.missingKey(key)
        }
        return value
    }

    private func double(_ key: String, _ values: [String: String]) throws -> Double {
        let value = try required(key, values)
        guard let parsed = Double(value) else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsed
    }

    private func int(_ key: String, _ values: [String: String]) throws -> Int {
        let value = try required(key, values)
        guard let parsed = Int(value) else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsed
    }

    private func int64(_ key: String, _ values: [String: String]) throws -> Int64 {
        let value = try required(key, values)
        guard let parsed = Int64(value) else {
            throw TelemetryParseError.invalidNumber(key: key, value: value)
        }
        return parsed
    }
}
```

- [ ] **Step 5: Add formatters**

Create `Sources/RemoteInfoCore/Support/Formatters.swift`:

```swift
import Foundation

public enum RemoteInfoFormatters {
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .binary)
    }

    public static func latency(_ seconds: TimeInterval) -> String {
        "\(Int((seconds * 1000).rounded())) ms"
    }

    public static func uptime(_ seconds: Int) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        return "\(hours)h"
    }
}
```

- [ ] **Step 6: Run tests and secret scan**

Run:

```bash
swift test --filter TelemetryParserTests
git add Sources/RemoteInfoCore/Models/HostTelemetry.swift Sources/RemoteInfoCore/Services/TelemetryParser.swift Sources/RemoteInfoCore/Support/Formatters.swift Tests/RemoteInfoCoreTests/TelemetryParserTests.swift
./script/check_no_secrets.sh
```

Expected: parser tests PASS and secret scan exits 0.

- [ ] **Step 7: Commit parser**

Run:

```bash
git commit -m "Add telemetry parser"
```

## Task 4: Add SSH Client And Telemetry Collector

**Files:**
- Create: `Sources/RemoteInfoCore/Models/TelemetryStatus.swift`
- Create: `Sources/RemoteInfoCore/Services/SSHClient.swift`
- Create: `Sources/RemoteInfoCore/Services/TelemetryCollector.swift`
- Create: `Tests/RemoteInfoCoreTests/TelemetryCollectorTests.swift`

- [ ] **Step 1: Write collector tests with fake SSH runner**

Create `Tests/RemoteInfoCoreTests/TelemetryCollectorTests.swift`:

```swift
import Foundation
import Testing
@testable import RemoteInfoCore

@Suite("TelemetryCollector")
struct TelemetryCollectorTests {
    @Test
    func collectsTelemetryFromSuccessfulSSHResult() async throws {
        let runner = FakeSSHRunner(result: SSHResult(
            stdout: """
            uptime_seconds=123456
            load1=0.42
            load5=0.38
            load15=0.31
            cpu_usage_percent=18.2
            memory_used_bytes=4412346368
            memory_total_bytes=10307921510
            root_used_bytes=77309411328
            root_total_bytes=107374182400
            """,
            stderr: "",
            exitCode: 0,
            elapsedSeconds: 0.25
        ))
        let collector = TelemetryCollector(sshRunner: runner, parser: TelemetryParser())

        let telemetry = try await collector.collect(for: HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"))

        #expect(telemetry.cpuUsagePercent == 18.2)
        #expect(telemetry.latencySeconds == 0.25)
    }

    @Test
    func reportsSSHFailure() async {
        let runner = FakeSSHRunner(result: SSHResult(
            stdout: "",
            stderr: "Permission denied",
            exitCode: 255,
            elapsedSeconds: 0.1
        ))
        let collector = TelemetryCollector(sshRunner: runner, parser: TelemetryParser())

        do {
            _ = try await collector.collect(for: HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"))
            Issue.record("Expected TelemetryCollectionError.sshFailed")
        } catch let error as TelemetryCollectionError {
            #expect(error == .sshFailed(exitCode: 255, message: "Permission denied"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private struct FakeSSHRunner: SSHRunning {
    let result: SSHResult

    func run(host: String, script: String, timeoutSeconds: TimeInterval) async throws -> SSHResult {
        #expect(host == "remote-info-host-a")
        #expect(script.contains("/proc/stat"))
        #expect(timeoutSeconds == 5)
        return result
    }
}
```

- [ ] **Step 2: Run collector tests to verify failure**

Run:

```bash
swift test --filter TelemetryCollectorTests
```

Expected: FAIL because `SSHRunning`, `SSHResult`, and `TelemetryCollector` do not exist.

- [ ] **Step 3: Implement telemetry status and errors**

Create `Sources/RemoteInfoCore/Models/TelemetryStatus.swift`:

```swift
import Foundation

public enum TelemetryStatus: Equatable, Sendable {
    case idle
    case loading
    case online
    case stale
    case offline(String)
}

public enum TelemetryCollectionError: Error, Equatable, LocalizedError {
    case sshFailed(exitCode: Int32, message: String)
    case parserFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sshFailed(_, let message):
            return message.isEmpty ? "SSH command failed." : message
        case .parserFailed(let message):
            return message
        }
    }
}
```

- [ ] **Step 4: Implement SSH runner**

Create `Sources/RemoteInfoCore/Services/SSHClient.swift`:

```swift
import Foundation

public struct SSHResult: Equatable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let elapsedSeconds: TimeInterval

    public init(stdout: String, stderr: String, exitCode: Int32, elapsedSeconds: TimeInterval) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.elapsedSeconds = elapsedSeconds
    }
}

public protocol SSHRunning: Sendable {
    func run(host: String, script: String, timeoutSeconds: TimeInterval) async throws -> SSHResult
}

public struct SSHClient: SSHRunning {
    public init() {}

    public func run(host: String, script: String, timeoutSeconds: TimeInterval) async throws -> SSHResult {
        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=\(Int(timeoutSeconds))",
            "-o", "StrictHostKeyChecking=accept-new",
            host,
            "sh", "-s"
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        let stdin = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdin

        try process.run()

        if let data = script.data(using: .utf8) {
            stdin.fileHandleForWriting.write(data)
        }
        try? stdin.fileHandleForWriting.close()

        let timedOut = await wait(for: process, timeoutSeconds: timeoutSeconds + 2)
        if timedOut {
            process.terminate()
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        return SSHResult(
            stdout: String(data: outputData, encoding: .utf8) ?? "",
            stderr: timedOut ? "Connection timed out" : (String(data: errorData, encoding: .utf8) ?? ""),
            exitCode: timedOut ? 124 : process.terminationStatus,
            elapsedSeconds: Date().timeIntervalSince(start)
        )
    }

    private func wait(for process: Process, timeoutSeconds: TimeInterval) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                process.waitUntilExit()
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                return process.isRunning
            }

            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }
}
```

- [ ] **Step 5: Implement telemetry collector**

Create `Sources/RemoteInfoCore/Services/TelemetryCollector.swift`:

```swift
import Foundation

public struct TelemetryCollector: Sendable {
    private let sshRunner: SSHRunning
    private let parser: TelemetryParser
    private let timeoutSeconds: TimeInterval

    public init(
        sshRunner: SSHRunning = SSHClient(),
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
            return try parser.parse(result.stdout, collectedAt: Date(), latency: result.elapsedSeconds)
        } catch {
            throw TelemetryCollectionError.parserFailed(error.localizedDescription)
        }
    }

    public static let remoteScript = """
    set -eu
    LC_ALL=C

    read _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
    total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1))
    idle_all1=$((idle1 + iowait1))
    sleep 0.2
    read _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat
    total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2))
    idle_all2=$((idle2 + iowait2))
    total_delta=$((total2 - total1))
    idle_delta=$((idle_all2 - idle_all1))
    cpu_usage=$(awk -v total="$total_delta" -v idle="$idle_delta" 'BEGIN { if (total <= 0) print "0.0"; else printf "%.1f", (total - idle) * 100 / total }')

    awk '{ printf "uptime_seconds=%.0f\\n", $1 }' /proc/uptime
    awk '{ print "load1="$1"\\nload5="$2"\\nload15="$3 }' /proc/loadavg
    printf 'cpu_usage_percent=%s\\n' "$cpu_usage"
    awk '/MemTotal:/ { total=$2 * 1024 } /MemAvailable:/ { available=$2 * 1024 } END { printf "memory_used_bytes=%.0f\\nmemory_total_bytes=%.0f\\n", total - available, total }' /proc/meminfo
    df -B1 / | awk 'NR==2 { print "root_used_bytes="$3"\\nroot_total_bytes="$2 }'
    """
}
```

- [ ] **Step 6: Run collector tests and secret scan**

Run:

```bash
swift test --filter TelemetryCollectorTests
git add Sources/RemoteInfoCore/Models/TelemetryStatus.swift Sources/RemoteInfoCore/Services/SSHClient.swift Sources/RemoteInfoCore/Services/TelemetryCollector.swift Tests/RemoteInfoCoreTests/TelemetryCollectorTests.swift
./script/check_no_secrets.sh
```

Expected: collector tests PASS and secret scan exits 0.

- [ ] **Step 7: Commit collector**

Run:

```bash
git commit -m "Add SSH telemetry collector"
```

## Task 5: Add Telemetry Store

**Files:**
- Create: `Sources/RemoteInfoCore/Stores/TelemetryStore.swift`
- Create: `Tests/RemoteInfoCoreTests/TelemetryStoreTests.swift`

- [ ] **Step 1: Write store tests with fake collector**

Create `Tests/RemoteInfoCoreTests/TelemetryStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import RemoteInfoCore

@MainActor
@Suite("TelemetryStore")
struct TelemetryStoreTests {
    @Test
    func refreshAllUpdatesHostsIndependently() async {
        let hosts = [
            HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"),
            HostConfig(id: "host-b", name: "Host B", sshTarget: "remote-info-host-b")
        ]
        let collector = FakeTelemetryCollecting(results: [
            "host-a": .success(sampleTelemetry(cpu: 10)),
            "host-b": .failure(TelemetryCollectionError.sshFailed(exitCode: 255, message: "Permission denied"))
        ])
        let store = TelemetryStore(hosts: hosts, collector: collector)

        await store.refreshAll()

        #expect(store.hostStates[0].status == .online)
        #expect(store.hostStates[0].telemetry?.cpuUsagePercent == 10)
        #expect(store.hostStates[1].status == .offline("Permission denied"))
        #expect(store.hostStates[1].telemetry == nil)
    }

    @Test
    func keepsLastSuccessfulTelemetryWhenLaterRefreshFails() async {
        let hosts = [
            HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"),
            HostConfig(id: "host-b", name: "Host B", sshTarget: "remote-info-host-b")
        ]
        let collector = QueueTelemetryCollecting(results: [
            .success(sampleTelemetry(cpu: 12)),
            .success(sampleTelemetry(cpu: 20)),
            .failure(TelemetryCollectionError.sshFailed(exitCode: 124, message: "Connection timed out")),
            .success(sampleTelemetry(cpu: 21))
        ])
        let store = TelemetryStore(hosts: hosts, collector: collector)

        await store.refreshAll()
        await store.refreshAll()

        #expect(store.hostStates[0].status == .offline("Connection timed out"))
        #expect(store.hostStates[0].telemetry?.cpuUsagePercent == 12)
        #expect(store.hostStates[1].status == .online)
        #expect(store.hostStates[1].telemetry?.cpuUsagePercent == 21)
    }
}

private func sampleTelemetry(cpu: Double) -> HostTelemetry {
    HostTelemetry(
        collectedAt: Date(timeIntervalSince1970: 100),
        latencySeconds: 0.1,
        uptimeSeconds: 10,
        load1: 0.1,
        load5: 0.1,
        load15: 0.1,
        cpuUsagePercent: cpu,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        rootUsedBytes: 3,
        rootTotalBytes: 4
    )
}

private struct FakeTelemetryCollecting: TelemetryCollecting {
    let results: [String: Result<HostTelemetry, Error>]

    func collect(for host: HostConfig) async throws -> HostTelemetry {
        try results[host.id]!.get()
    }
}

private final class QueueTelemetryCollecting: TelemetryCollecting, @unchecked Sendable {
    private var results: [Result<HostTelemetry, Error>]

    init(results: [Result<HostTelemetry, Error>]) {
        self.results = results
    }

    func collect(for host: HostConfig) async throws -> HostTelemetry {
        try results.removeFirst().get()
    }
}
```

- [ ] **Step 2: Run store tests to verify failure**

Run:

```bash
swift test --filter TelemetryStoreTests
```

Expected: FAIL because `TelemetryStore`, `HostState`, and `TelemetryCollecting` do not exist.

- [ ] **Step 3: Add collector protocol conformance**

Modify `Sources/RemoteInfoCore/Services/TelemetryCollector.swift` by inserting the protocol above `TelemetryCollector` and changing the struct declaration:

```diff
 import Foundation

+public protocol TelemetryCollecting: Sendable {
+    func collect(for host: HostConfig) async throws -> HostTelemetry
+}
+
-public struct TelemetryCollector: Sendable {
+public struct TelemetryCollector: TelemetryCollecting, Sendable {
     private let sshRunner: SSHRunning
     private let parser: TelemetryParser
     private let timeoutSeconds: TimeInterval
```

- [ ] **Step 4: Implement telemetry store**

Create `Sources/RemoteInfoCore/Stores/TelemetryStore.swift`:

```swift
import Combine
import Foundation

public struct HostState: Equatable, Identifiable, Sendable {
    public let host: HostConfig
    public var telemetry: HostTelemetry?
    public var status: TelemetryStatus
    public var isRefreshing: Bool

    public var id: String { host.id }

    public init(host: HostConfig, telemetry: HostTelemetry? = nil, status: TelemetryStatus = .idle, isRefreshing: Bool = false) {
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

    private let collector: TelemetryCollecting
    private var inFlightHostIDs: Set<String> = []
    private var periodicTask: Task<Void, Never>?

    public init(hosts: [HostConfig], collector: TelemetryCollecting = TelemetryCollector()) {
        self.hostStates = hosts.map { HostState(host: $0) }
        self.collector = collector
    }

    deinit {
        periodicTask?.cancel()
    }

    public var onlineCount: Int {
        hostStates.filter { $0.status == .online || $0.status == .stale }.count
    }

    public var errorCount: Int {
        hostStates.filter {
            if case .offline = $0.status { return true }
            return false
        }.count
    }

    public func refreshAll() async {
        lastRefreshStartedAt = Date()
        await withTaskGroup(of: Void.self) { group in
            for host in hostStates.map(\.host) {
                group.addTask { [weak self] in
                    await self?.refresh(hostID: host.id)
                }
            }
        }
    }

    public func startPeriodicRefresh(every seconds: TimeInterval = 60) {
        periodicTask?.cancel()
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshAll()
                try? await Task.sleep(for: .seconds(seconds))
            }
        }
    }

    public func stopPeriodicRefresh() {
        periodicTask?.cancel()
        periodicTask = nil
    }

    private func refresh(hostID: String) async {
        guard !inFlightHostIDs.contains(hostID),
              let index = hostStates.firstIndex(where: { $0.id == hostID }) else {
            return
        }

        inFlightHostIDs.insert(hostID)
        hostStates[index].isRefreshing = true
        if hostStates[index].telemetry == nil {
            hostStates[index].status = .loading
        }

        let host = hostStates[index].host
        do {
            let telemetry = try await collector.collect(for: host)
            if let currentIndex = hostStates.firstIndex(where: { $0.id == hostID }) {
                hostStates[currentIndex].telemetry = telemetry
                hostStates[currentIndex].status = .online
                hostStates[currentIndex].isRefreshing = false
            }
        } catch {
            if let currentIndex = hostStates.firstIndex(where: { $0.id == hostID }) {
                hostStates[currentIndex].status = .offline(error.localizedDescription)
                hostStates[currentIndex].isRefreshing = false
            }
        }

        inFlightHostIDs.remove(hostID)
    }
}
```

- [ ] **Step 5: Run store tests and full tests**

Run:

```bash
swift test --filter TelemetryStoreTests
swift test
git add Sources/RemoteInfoCore/Stores/TelemetryStore.swift Sources/RemoteInfoCore/Services/TelemetryCollector.swift Tests/RemoteInfoCoreTests/TelemetryStoreTests.swift
./script/check_no_secrets.sh
```

Expected: store tests PASS, full tests PASS, and secret scan exits 0.

- [ ] **Step 6: Commit store**

Run:

```bash
git commit -m "Add telemetry refresh store"
```

## Task 6: Build Polished Native Menu Bar Panel

**Files:**
- Modify: `Sources/RemoteInfoApp/App/RemoteInfoApp.swift`
- Modify: `Sources/RemoteInfoApp/Views/MenuBarPanelView.swift`
- Create: `Sources/RemoteInfoApp/Views/FleetSummaryView.swift`
- Create: `Sources/RemoteInfoApp/Views/HostCardView.swift`
- Create: `Sources/RemoteInfoApp/Views/MetricView.swift`

- [ ] **Step 1: Wire config loading and store into app entry**

Replace `Sources/RemoteInfoApp/App/RemoteInfoApp.swift`:

```swift
import RemoteInfoCore
import SwiftUI

@main
struct RemoteInfoApp: App {
    @StateObject private var store = AppStoreFactory.makeStore()

    var body: some Scene {
        MenuBarExtra("Remote Info", systemImage: menuBarIconName) {
            MenuBarPanelView(store: store)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIconName: String {
        store.errorCount > 0 ? "server.rack" : "server.rack"
    }
}

private enum AppStoreFactory {
    @MainActor
    static func makeStore() -> TelemetryStore {
        do {
            let hosts = try HostConfigLoader().loadDefault()
            let store = TelemetryStore(hosts: hosts)
            Task {
                await store.refreshAll()
                store.startPeriodicRefresh()
            }
            return store
        } catch {
            let sampleHosts = [
                HostConfig(id: "host-a", name: "Host A", sshTarget: "remote-info-host-a"),
                HostConfig(id: "host-b", name: "Host B", sshTarget: "remote-info-host-b")
            ]
            return TelemetryStore(hosts: sampleHosts)
        }
    }
}
```

- [ ] **Step 2: Replace panel composition**

Replace `Sources/RemoteInfoApp/Views/MenuBarPanelView.swift`:

```swift
import RemoteInfoCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var store: TelemetryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            FleetSummaryView(store: store)
            hostCards
            footer
        }
        .padding(16)
        .frame(width: 420)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Remote Info")
                    .font(.headline)
                Text("Last refresh \(lastRefreshText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await store.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .help("Refresh")
        }
    }

    private var hostCards: some View {
        VStack(spacing: 10) {
            ForEach(store.hostStates) { state in
                HostCardView(state: state)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Config: ~/.config/remote-info/hosts.json")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
        }
    }

    private var lastRefreshText: String {
        guard let date = store.lastRefreshStartedAt else {
            return "not started"
        }
        return date.formatted(.relative(presentation: .named))
    }
}
```

- [ ] **Step 3: Add fleet summary view**

Create `Sources/RemoteInfoApp/Views/FleetSummaryView.swift`:

```swift
import RemoteInfoCore
import SwiftUI

struct FleetSummaryView: View {
    @ObservedObject var store: TelemetryStore

    var body: some View {
        HStack(spacing: 8) {
            summaryCell(label: "ONLINE", value: "\(store.onlineCount)/\(store.hostStates.count)")
            summaryCell(label: "LOAD", value: worstLoadText)
            summaryCell(label: "ERRORS", value: "\(store.errorCount)")
        }
    }

    private var worstLoadText: String {
        let loads = store.hostStates.compactMap { $0.telemetry?.load1 }
        guard let maxLoad = loads.max() else { return "--" }
        return String(format: "%.2f", maxLoad)
    }

    private func summaryCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 4: Add metric view**

Create `Sources/RemoteInfoApp/Views/MetricView.swift`:

```swift
import SwiftUI

struct MetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded).weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 5: Add host card view**

Create `Sources/RemoteInfoApp/Views/HostCardView.swift`:

```swift
import RemoteInfoCore
import SwiftUI

struct HostCardView: View {
    let state: HostState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.host.name)
                        .font(.headline)
                    Text(state.host.sshTarget)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                statusBadge
            }

            if let telemetry = state.telemetry {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricView(label: "CPU", value: RemoteInfoFormatters.percent(telemetry.cpuUsagePercent))
                    MetricView(label: "LOAD", value: String(format: "%.2f", telemetry.load1))
                    MetricView(label: "MEM", value: RemoteInfoFormatters.percent(telemetry.memoryUsagePercent))
                    MetricView(label: "DISK", value: RemoteInfoFormatters.percent(telemetry.rootUsagePercent))
                    MetricView(label: "UPTIME", value: RemoteInfoFormatters.uptime(telemetry.uptimeSeconds))
                    MetricView(label: "SSH", value: RemoteInfoFormatters.latency(telemetry.latencySeconds))
                }
            } else {
                Text("No telemetry collected yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if case .offline(let message) = state.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }

    private var statusText: String {
        if state.isRefreshing {
            return "refreshing"
        }
        switch state.status {
        case .idle:
            return "idle"
        case .loading:
            return "loading"
        case .online:
            return "online"
        case .stale:
            return "stale"
        case .offline:
            return "offline"
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .online:
            return .green
        case .loading:
            return .blue
        case .stale:
            return .orange
        case .offline:
            return .red
        case .idle:
            return .secondary
        }
    }
}
```

- [ ] **Step 6: Build, run tests, and verify app**

Run:

```bash
swift test
swift build
./script/build_and_run.sh --verify
git add Sources/RemoteInfoApp
./script/check_no_secrets.sh
```

Expected: tests PASS, build PASS, `--verify` exits 0, and the menu bar panel opens with native SwiftUI controls.

- [ ] **Step 7: Commit UI**

Run:

```bash
git commit -m "Build native telemetry panel"
```

## Task 7: Final Validation And Remote Setup Notes

**Files:**
- Modify: `README.md`
- No tracked file should contain the user's real host config.

- [ ] **Step 1: Create local host config outside repo**

Run:

```bash
mkdir -p ~/.config/remote-info
cp config/hosts.example.json ~/.config/remote-info/hosts.json
chmod 600 ~/.config/remote-info/hosts.json
```

Edit `~/.config/remote-info/hosts.json` locally so each `sshTarget` is an alias that already works with:

```bash
ssh -o BatchMode=yes remote-info-host-a true
ssh -o BatchMode=yes remote-info-host-b true
```

Do not copy the edited file into the repository.

- [ ] **Step 2: Manually validate SSH command output**

Run this through one configured alias:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 remote-info-host-a sh -s < /tmp/remote-info-probe.sh
```

Before running it, create `/tmp/remote-info-probe.sh` from the `TelemetryCollector.remoteScript` string. Expected output contains only key/value telemetry lines and no secrets.

- [ ] **Step 3: Validate app with real local config**

Run:

```bash
./script/build_and_run.sh --verify
```

Expected: menu bar app launches, panel shows two configured hosts, manual refresh updates both cards, and one unreachable host does not break the other card.

- [ ] **Step 4: Update README with validation commands**

Append to `README.md`:

```markdown
## Validation

Run the test suite:

```bash
swift test
```

Build and launch the native menu bar app:

```bash
./script/build_and_run.sh --verify
```

Check that no sensitive markers are staged before committing:

```bash
git add <files>
./script/check_no_secrets.sh
```
```

- [ ] **Step 5: Run final checks**

Run:

```bash
swift test
swift build
git status --short
git add README.md
./script/check_no_secrets.sh
git diff --cached --check
```

Expected: tests PASS, build PASS, secret scan exits 0, whitespace check exits 0.

- [ ] **Step 6: Commit final docs**

Run:

```bash
git commit -m "Document remote info setup"
```

## Final Security Gate

Before pushing or opening a pull request, run:

```bash
git ls-files -z \
  | grep -zvE '^(script/check_no_secrets.sh|docs/superpowers/plans/)' \
  | xargs -0 rg -n --pcre2 -- '-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}' || true
git status --short
```

Expected: no private-key or token matches. The only modified or untracked files should be intentional.
