# Mock Telemetry Mode Design

## Goal

Add an explicit mock data mode so the menu bar UI can be tuned without connecting to real Linux hosts.

## Behavior

- Default launch keeps the current production path: load `~/.config/remote-info/hosts.json`, then collect telemetry through SSH.
- Mock mode is opt-in through `./script/build_and_run.sh --mock`.
- Mock mode does not read the local host config and does not run SSH.
- Mock mode uses two in-memory hosts with plausible, changing telemetry values.
- The menu panel shows a small mock-mode configuration note so the data source is visible during UI work.

## Implementation

- Add `MockTelemetryCollector` in `RemoteInfoCore`.
- Add an app launch environment variable, `REMOTE_INFO_MOCK_MODE=1`, used only by the app bootstrap.
- In mock mode, bootstrap `TelemetryStore` with mock hosts and `MockTelemetryCollector`.
- Extend `script/build_and_run.sh` with `--mock`.

## Verification

- Unit tests cover that mock collection returns telemetry and changes over repeated refreshes.
- App bootstrap tests cover that mock mode bypasses config loading and enables refresh.
- Existing SSH/config behavior remains the default.
