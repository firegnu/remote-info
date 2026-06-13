# Remote Info Design

## Purpose

Remote Info is a personal macOS menu bar app for checking the health of two remote Linux hosts. "Personal use" means the app does not need App Store distribution, multi-user onboarding, or enterprise deployment. It should still feel like a reliable daily tool: responsive, readable, polished, and explicit about failures.

The first version uses direct SSH collection. The Linux hosts do not need an installed agent, open monitoring port, or Prometheus setup.

The app must be a native macOS app built with Swift and SwiftUI, using native system menu bar and window/panel APIs. Electron, Tauri, React Native, web dashboards, WebView shells, and browser-based UI are out of scope.

## Product Scope

### In Scope

- A menu-bar-only macOS app.
- Native Swift/SwiftUI implementation.
- A polished popover/window panel opened from the menu bar icon.
- Two configured Linux hosts.
- Direct SSH telemetry collection through `/usr/bin/ssh`.
- Reuse of the user's local SSH configuration, keys, and ssh-agent.
- Live snapshot metrics:
  - online/offline status
  - SSH latency
  - CPU usage
  - load average
  - memory usage
  - root filesystem disk usage
  - uptime
  - last refresh time
- Manual refresh.
- Periodic refresh.
- Per-host error display.
- Light/Dark Mode adaptive UI.
- Parser and store tests for the collection path.

### Out Of Scope

- App Store packaging and review requirements.
- Electron, Tauri, React Native, WebView shells, or browser-based dashboards.
- Username/password login UI.
- Saving SSH credentials inside the app.
- Installing a remote Linux agent.
- Prometheus, node_exporter, Grafana, or a metrics database.
- Historical charts and long-term trend storage.
- Notification and alert rules.
- Docker, nginx, database, or service-specific monitoring in version one.
- More than two hosts in the first version.

## User Experience

The app lives in the macOS menu bar. It intentionally has no Dock icon and no primary app window at launch.

Clicking the menu bar icon opens a compact but polished operations panel. The selected direction is "Polished Operations Panel":

- Header with app name, fleet status, last refresh age, and refresh action.
- Small summary row with online host count, worst load/health indicator, and error count.
- Two host cards, one per Linux host.
- Each host card shows status, latency, CPU, load, memory, disk, uptime, and last successful update.
- Errors are shown in the affected host card without hiding the last known successful values.
- A Quit action is available from the panel.
- A Settings entry can be reserved visually or structurally, but a full settings workflow is not required for version one.

The panel should be useful at a glance. It should not become a miniature Grafana dashboard.

## Architecture

Use a native Swift/SwiftUI macOS app with focused files and explicit boundaries.

Expected structure:

- `App/RemoteInfoApp.swift`
  - App entry point.
  - Defines `MenuBarExtra`.
  - Documents that menu-bar-only behavior is intentional.
- `Models/HostConfig.swift`
  - Static host identity and SSH target.
- `Models/HostTelemetry.swift`
  - Latest structured metrics for one host.
- `Models/TelemetryStatus.swift`
  - Loading, online, stale, offline, and error states.
- `Services/SSHClient.swift`
  - Runs `/usr/bin/ssh`.
  - Applies timeouts and batch mode.
  - Returns raw stdout, stderr, exit status, and elapsed time.
- `Services/TelemetryCollector.swift`
  - Builds the remote read-only command.
  - Calls `SSHClient`.
  - Converts command result into telemetry or error.
- `Services/TelemetryParser.swift`
  - Parses stable key/value output into `HostTelemetry`.
- `Stores/TelemetryStore.swift`
  - Owns host states.
  - Triggers initial, manual, and periodic refresh.
  - Keeps refreshes asynchronous and per-host isolated.
- `Views/MenuBarPanelView.swift`
  - Panel composition.
- `Views/FleetSummaryView.swift`
  - Top summary row.
- `Views/HostCardView.swift`
  - Per-host card.
- `Views/MetricView.swift`
  - Reusable compact metric presentation.
- `Support/Formatters.swift`
  - Percent, duration, bytes, latency, and relative time formatting.

## SSH Collection

The app calls `/usr/bin/ssh` rather than linking an SSH library. This keeps the first version aligned with local macOS SSH behavior and avoids credential handling inside the app.

SSH constraints:

- Use the host alias or target from `HostConfig`.
- Reuse `~/.ssh/config`.
- Reuse existing keys and ssh-agent.
- Use `BatchMode=yes`.
- Use a short `ConnectTimeout`.
- Avoid interactive prompts.
- Run one read-only remote collection command per host refresh.
- Collect both hosts concurrently.
- A failure on one host must not block or alter the other host's refresh.

The remote command should output stable key/value lines rather than human-formatted tables. That keeps parsing deterministic across common Linux distributions.

Example output shape:

```text
uptime_seconds=123456
load1=0.42
load5=0.38
load15=0.31
cpu_usage_percent=18.2
memory_used_bytes=4412346368
memory_total_bytes=10307921510
root_used_bytes=77309411328
root_total_bytes=107374182400
```

If a metric cannot be collected, the parser should report a structured partial-data error instead of silently treating it as zero.

## Refresh Behavior

- Refresh immediately when the app starts.
- Support manual refresh from the panel.
- Refresh periodically, with a default interval of 60 seconds.
- Do not start overlapping refreshes for the same host.
- Allow different hosts to refresh independently.
- Show active refresh state without blocking the UI.
- Keep the last successful telemetry visible when a refresh fails.
- Mark data as stale if it is older than the configured freshness window.

## Error Handling

Errors should be explicit and actionable enough for personal troubleshooting.

Expected categories:

- SSH unavailable locally.
- DNS or host unreachable.
- SSH authentication failed or requires interaction.
- Connection timeout.
- Remote command failed.
- Parser failed because output was missing or malformed.

Each host card should show the current error and the last successful refresh time when available.

The app should not retry in a tight loop. Periodic refresh is enough for version one.

## Configuration

Version one uses a local file-backed host configuration rather than committing real host details to source control. The repository can include a non-sensitive example file with placeholder host aliases, but the real two-host configuration should live outside tracked source, such as `~/.config/remote-info/hosts.json`.

The app should not store private keys, passwords, passphrases, tokens, or real host secrets in tracked files.

## Quality Bar

The first version is not a throwaway prototype. It should meet these standards:

- Native SwiftUI macOS feel.
- No Dock icon unless intentionally changed later.
- Responsive UI during SSH refreshes.
- Clear loading, success, stale, and failure states.
- Good layout at expected menu bar panel sizes.
- No text clipping in host cards.
- Light/Dark Mode support through semantic colors and system materials.
- Small focused files.
- Unit tests for telemetry parsing and store behavior.
- Manual verification against reachable and unreachable host states.

## Validation Plan

- Build the macOS app from a clean checkout.
- Run unit tests for parser behavior:
  - valid full output
  - missing metric
  - malformed numeric value
  - extra unknown key
- Test SSH client behavior with:
  - valid host alias
  - unreachable host
  - authentication failure or `BatchMode` failure
  - timeout
- Run the app locally and verify:
  - menu bar icon appears
  - panel opens from menu bar
  - manual refresh updates both hosts
  - one failed host does not break the other host card
  - stale data remains visible with an error label
  - layout is readable in Light and Dark Mode

## Risks And Mitigations

- Linux command output can vary by distribution.
  - Mitigation: output key/value lines from `/proc`, `df`, and shell arithmetic instead of parsing localized table output.
- CPU usage requires sampling over time.
  - Mitigation: collect two `/proc/stat` snapshots inside one remote command with a short sleep, then calculate usage.
- SSH can hang if it prompts for input.
  - Mitigation: use `BatchMode=yes`, short connect timeout, and no password UI.
- Menu bar panels can become cramped.
  - Mitigation: keep version one to two host cards and summary metrics only.
- Local host configuration can be missing or malformed.
  - Mitigation: show a clear setup error and keep a non-sensitive example config in the repository.
