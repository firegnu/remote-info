# Remote Info

Remote Info is a native SwiftUI macOS menu bar app for viewing information from two Linux hosts through direct SSH.

## Host Configuration

Create a local configuration directory and copy the safe example config:

```bash
mkdir -p ~/.config/remote-info
cp config/hosts.example.json ~/.config/remote-info/hosts.json
chmod 600 ~/.config/remote-info/hosts.json
```

Edit `~/.config/remote-info/hosts.json` locally so each `sshTarget` matches an SSH config alias or safe target name for your machine. The copied `CHANGE_ME_*` values are rejected by the app until you replace them.

Test the configured aliases after editing your local SSH config:

```bash
ssh -o BatchMode=yes your-host-a-alias true
ssh -o BatchMode=yes your-host-b-alias true
```

Do not copy the edited local config into this repo. If the config is missing, malformed, or still contains placeholders, the app shows the configuration error and disables refresh instead of connecting to those targets.

## Security

Do not commit SSH keys, passwords, passphrases, tokens, real hostnames, or IdentityFile paths. Keep local host details in `~/.config/remote-info/hosts.json`; `config/hosts.local.json` is ignored by Git for local experiments.

Remote Info uses `/usr/bin/ssh` and does not store keys or passwords.

## GPU Telemetry

When `nvidia-smi` is available on a remote host, Remote Info collects GPU telemetry with `nvidia-smi --query-gpu`. No remote daemon is required. Hosts without NVIDIA telemetry still report system metrics; the GPU panel is omitted for those hosts.

## Activity Telemetry

Remote Info also shows the top CPU-consuming processes and the default network interface. Process telemetry uses `ps` short command names only, not full command lines or arguments. Network telemetry reads the default outbound interface and `/proc/net/dev` counters over the existing one-second sample window.

## Refresh Behavior

Remote Info refreshes once when the app starts, then refreshes every five minutes. Opening the menu bar panel does not force a refresh; use the refresh button for an on-demand update.

## Development

Tests may require full Xcode rather than Command Line Tools. If `swift test` cannot import XCTest, use the `DEVELOPER_DIR` prefix.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
swift build
./script/build_and_run.sh --verify
```

Use mock telemetry, including RTX 5090 GPU data, while adjusting the menu bar UI without connecting to real hosts:

```bash
./script/build_and_run.sh --mock
```

Before committing, stage the intended files and run the staged secret scan:

```bash
git add <files>
./script/check_no_secrets.sh
```
