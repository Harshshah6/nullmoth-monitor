# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-21

### Added

- Control panel tab next to the live monitor.
- Display mode control: per-display resolution and refresh rate, straight from
  CoreGraphics. macOS often leaves modes out of System Settings on a
  Hackintosh. Applying a mode needs no administrator rights and is not written
  to disk.
- Driver setup doctor: audits boot arguments and `csr-active-config` against the
  NullMoth documentation and offers a corrected `boot-args` string to copy.
  Read-only.
- Capability report: Metal family, argument buffers, ray tracing, MPS, hardware
  H.264/HEVC encode and decode, OpenGL through GL-on-Metal, and the GSP firmware
  version.
- Driver update check: compares the installed driver with the latest NullMoth
  release. The request is only made when the user asks for it and downloads
  nothing.
- CLI commands: `--doctor`, `--modes`, `--capabilities`, and `--check-update`.
- `--show-monitor` and `--show-control` launch arguments for UI checks.

### Changed

- The app is now a monitor **and** a control panel. The menu bar item opens
  either tab.
- The footer no longer says "read-only": applying a display mode is the one
  change the app can make.

## [0.1.2] - 2026-11-21

### Fixed

- Metal 4 is now detected at runtime instead of behind a compile-time check.
  Release binaries built with an older Xcode reported Metal 3 even on macOS 26.

## [0.1.1] - 2026-11-21

### Fixed

- Release builds are now universal (`x86_64` + `arm64`). `v0.1.0` was built on
  an Apple Silicon runner, so Intel Hackintoshes rejected it with “this
  application is not supported on this Mac.”
- CI and the release workflow verify both architecture slices before publishing.
- Releases now also attach the universal `nullmoth-mon` CLI and a combined
  `SHA256SUMS` file.

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

[Unreleased]: https://github.com/Harshshah6/nullmoth-monitor/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Harshshah6/nullmoth-monitor/releases/tag/v0.2.0
[0.1.2]: https://github.com/Harshshah6/nullmoth-monitor/releases/tag/v0.1.2
[0.1.1]: https://github.com/Harshshah6/nullmoth-monitor/releases/tag/v0.1.1
[0.1.0]: https://github.com/Harshshah6/nullmoth-monitor/releases/tag/v0.1.0
