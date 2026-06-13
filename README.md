# Remote Info

Remote Info is a native SwiftUI macOS menu bar app for viewing information from two Linux hosts through direct SSH.

## Host Configuration

Create a local configuration directory and copy the safe example config:

```bash
mkdir -p ~/.config/remote-info
cp config/hosts.example.json ~/.config/remote-info/hosts.json
```

Edit `~/.config/remote-info/hosts.json` locally so each `sshTarget` matches an SSH config alias or safe target name for your machine.

## Security

Do not commit SSH keys, passwords, passphrases, tokens, real hostnames, or IdentityFile paths. Keep local host details in `~/.config/remote-info/hosts.json`; `config/hosts.local.json` is ignored by Git for local experiments.

Remote Info uses `/usr/bin/ssh` and does not store keys or passwords.

## Development

The package can be built with SwiftPM:

```bash
swift build
```

Tests may require full Xcode rather than Command Line Tools. If `swift test` cannot import XCTest, run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
