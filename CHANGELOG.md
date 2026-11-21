# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-21

### Added

- Native menu bar app with a SwiftUI popover.
- Live GPU core, memory, encode, and decode utilization.
- GPU temperature, VRAM in use, Metal family, and ray-tracing support.
- Utilization sparkline with session history.
- Display names, pixel resolution, refresh rate, and main-display flag.
- NVIDIA HDMI/DP audio outputs and the current default output.
- Driver health: NVRM/NVAccel/NVRMFB/NVRMAGDC load state and versions, Metal
  plugin version, SIP status, and boot-argument checks.
- Optional SMC fan RPM when the hardware exposes `FNum`/`F<n>Ac`.
- `nullmoth-mon` CLI with summary, JSON, Markdown report, and watch modes.
- Redacted Markdown report with no serial numbers, UUIDs, or EDIDs.
- Pause, refresh, and copy-report controls.
- Deterministic app icon generated from `Scripts/GenerateIcon.swift`.
- Unit tests for parsers, boot-argument diagnostics, and report output.
- CI and tag-release GitHub Actions workflows.

[Unreleased]: https://github.com/OWNER/nullmoth-monitor/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/OWNER/nullmoth-monitor/releases/tag/v0.1.0
