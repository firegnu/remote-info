# GPU Telemetry Design

## Decision

Use the selected B layout: each host card keeps compact system metrics, then renders a dedicated GPU panel for RTX 5090 telemetry.

## Collection

Use `nvidia-smi --query-gpu` as the primary remote data source instead of parsing `nvitop` output. `nvidia-smi` is designed for stable machine-readable output, while `nvitop` is better for interactive terminal monitoring.

Collect these fields per GPU:

- `index`
- `name`
- `driver_version`
- `utilization.gpu`
- `memory.used`
- `memory.total`
- `temperature.gpu`
- `power.draw`
- `power.limit`
- `fan.speed`
- `clocks.current.graphics`

The remote script should tolerate hosts without NVIDIA telemetry by returning the existing system telemetry and an empty GPU list. SSH failures should still mark the host offline.

## Model

Add a `GPUTelemetry` value model and attach `[GPUTelemetry]` to `HostTelemetry`.

Computed values:

- VRAM usage percentage from used and total MiB.
- Power usage percentage from draw and limit watts.

## Parsing

Keep the existing key-value parser for system telemetry. Add a GPU line format that is explicit and easy to split, for example:

```text
gpu=0|NVIDIA GeForce RTX 5090|575.xx|88|29800|32768|72|512|575|64|2620
```

The parser should reject malformed GPU numeric fields but allow no `gpu=` lines.

## UI

For each host with GPUs:

- Show a dedicated panel below CPU/MEM/SSH.
- Header: GPU name, GPU index, VRAM class and driver.
- Bars: utilization and VRAM.
- Small stats: power, fan, graphics clock.
- Temperature appears in the panel header as a scan target.

If a host has no GPU data, omit the panel rather than showing empty placeholders.

## Mock Mode

Mock mode should include one RTX 5090 per mock host, with changing utilization, VRAM, temperature, power, fan and clock values. This keeps UI review independent from real machines.

## Verification

- Parser tests for complete GPU lines, missing GPU lines, and malformed GPU numeric values.
- Collector test that remote script asks `nvidia-smi --query-gpu`.
- Mock collector tests for GPU data and changing values.
- UI/build verification through existing Swift tests and `./script/build_and_run.sh --mock`.
