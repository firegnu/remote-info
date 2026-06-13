# Activity Telemetry Design

## Goal

Add compact per-host activity telemetry to show the CPU-heavy processes and default network interface status in the existing macOS menu bar panel.

## Scope

- Show the top three processes by CPU usage.
- Show the default outbound network interface, link state, receive rate, transmit rate, and total interface errors/drops.
- Support mock mode so the UI can be reviewed without connecting to real hosts.
- Keep collection through direct SSH with a POSIX shell script.

## Non-Goals

- No remote daemon.
- No full command lines, arguments, environment variables, usernames, hostnames, or paths in process telemetry.
- No public ping target or active network probing.
- No process killing, network actions, alerts, or history charts.

## Data Shape

Process rows:

```text
process=<pid>|<command>|<cpu_percent>|<memory_percent>
```

Network row:

```text
network=<interface>|<operstate>|<receive_bytes_per_second>|<transmit_bytes_per_second>|<receive_errors>|<transmit_errors>|<receive_drops>|<transmit_drops>
```

Process rows are optional and repeatable. The network row is optional and should appear at most once.

## Remote Collection

Processes use:

```sh
ps -eo pid=,comm=,pcpu=,pmem= --sort=-pcpu | head -n 3
```

The `comm` column is used instead of the full command line to avoid leaking tokens, paths, or command arguments.

Network uses the default route interface from `ip route get 1.1.1.1`. If that fails, the collector falls back to the first non-loopback interface. Rates use a one-second delta from `/proc/net/dev`, reusing the existing CPU sampling sleep.

## UI Placement

Add an `Activity` section below the basic metrics grid and above GPU telemetry:

```text
NET   eth0 up   down 18.4 MB/s   up 3.2 MB/s   err 0
CPU   python3 216%   ollama 94%   ffmpeg 18%
```

Missing process or network rows are omitted. The host should remain online if base metrics parse successfully.
