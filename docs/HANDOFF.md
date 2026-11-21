# Handoff notes

Last updated: 2026-11-21

This file is the continuity document for a new maintainer or AI agent. It records
what exists, what was verified, why decisions were made, and what to do next.

## 1. What this project is

**NullMoth Monitor** is a native macOS menu bar app and CLI for Hackintosh users
running the [NullMoth NVIDIA driver](https://github.com/nullmoth/nvidia-macos-driver).
It is a read-only companion: it observes the driver and system state, and never
changes them.

It is deliberately **not** an installer. The 1401 app already handles install,
update, rollback, and log upload. This project focuses on live monitoring and
diagnostics.

- Repository: <https://github.com/Harshshah6/nullmoth-monitor>
- License: MIT (the driver remains under its own PolyForm Noncommercial license)
- Bundle identifier: `io.github.nullmothmonitor.app`
- Current version: `0.1.1`

## 2. Current status

### Done

- Swift package with `NullMothCore`, `nullmoth-mon`, and `NullMothMonitor`.
- Read-only probes: GPU, Metal, displays, audio, driver, system, SMC fans.
- Menu bar app with popover, sparkline, pause/refresh/copy-report controls.
- CLI modes: summary, `--json`, `--report`, `--watch`, `--help`.
- 31 unit tests for parsers, boot-argument checks, and report output.
- App icon generated from `Scripts/GenerateIcon.swift` and bundled as `.icns`.
- CI and tag-release GitHub Actions workflows.
- Universal release build (`make app-universal`) with `lipo` and CI checks for
  both `x86_64` and `arm64` slices.
- README, CONTRIBUTING, SECURITY, issue/PR templates, `.editorconfig`.
- `docs/` with handoff notes, publishing steps, a changelog, and an index.
- Git repository initialized with an initial history.

### Verified on real hardware

Test machine:

- macOS 26.7.3 (25G342), x86_64, MacPro7,1
- Xcode 26.5, Swift 6.3.2
- NVIDIA GeForce RTX 3060 12 GB, Metal 4, device-id `0x2504`
- NullMoth driver 3.0; `com.nullmoth.NVRM`, `NVAccel`, `NVRMFB`, `NVRMAGDC`
  all loaded
- `/Library/GPUBundles/NVMTLDriver.bundle` version `0.1`
- Displays: `MSI MP223` 1920×1080 @ 100 Hz (main); `LCD-MONITOR` 1366×768 @ 60 Hz
- Audio: four `NVIDIA (0x009f) (HDMI/DP 8ch)` outputs; default output is a USB
  PnP audio device
- Fans: SMC exposes no `FNum`/`F<n>Ac`, so the fan list is empty by design
- SIP: `Custom Configuration`
- Boot args: `debug=0x100 -dbgenhdbg keepsyms=1 -amfipassbeta revpatch=sbvmm nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 gfxrst=4 -v`

Observed CLI output:

```
NullMoth Monitor
  GPU:          NVIDIA GeForce RTX 3060
  Driver:       3.0
  Metal:        Metal 4
  Utilization:  8% core, 2% memory, 0% encode, 0% decode
  Temperature:  51°C
  VRAM:         445.4 MB used / 12 GB
  Displays:     2
    1. MSI MP223 — 1920x1080 @ 100 Hz (main)
    2. LCD-MONITOR — 1366x768 @ 60 Hz
  Audio:        4 NVIDIA HDMI/DP output(s); default: USB PnP Audio Device
  Kexts:        4/4 loaded
  Plugin:       installed 0.1
  SIP:          Custom Configuration
  Boot args:    OK
  Fans:         not exposed by the SMC
```

Also verified:

- `--json` is valid JSON with stderr redirected; the driver logs to stderr.
- `--watch` prints one line per second.
- `make app` produces a codesign-verifiable bundle at
  `build/NullMoth Monitor.app`.
- `make app-universal` produces a universal bundle; `lipo -archs` reports
  `x86_64 arm64`.
- The universal app and universal CLI both run on the Intel test machine.
- The app launches as an accessory and idles at roughly 0% CPU.

## 3. Environment and reproduction

Requirements:

- macOS 14 or later to run. macOS 14–26 are supported.
- Xcode command line tools with Swift 5.9 or later to build.
- Xcode 26 or later is recommended for release builds so Metal 4 detection is
  compiled in. Older SDKs still build; they simply report Metal 3 at most.
- The NullMoth driver is required for live GPU data, but not for building or
  testing.

Commands:

```sh
swift build
swift test
make app              # host-architecture bundle
make app-universal    # universal bundle for release
open "build/NullMoth Monitor.app"
```

CLI:

```sh
.build/debug/nullmoth-mon
.build/debug/nullmoth-mon --json 2>/dev/null
.build/debug/nullmoth-mon --report 2>/dev/null
.build/debug/nullmoth-mon --watch
```

## 4. Architecture

```
Sources/NullMothCore/
  Models.swift        Codable, Equatable, Sendable snapshot models
  MonitorProbe.swift  MonitorProbe.snapshot() — single entry point
  GPUProbe.swift      NVAccel PerformanceStatistics + NVRM + Metal
  DisplayProbe.swift  CGGetOnlineDisplayList + NSScreen names
  AudioProbe.swift    CoreAudio device enumeration
  DriverProbe.swift   kmutil, nvram, csrutil, plugin bundle
  SMCProbe.swift      AppleSMC FNum / F<n>Ac
  SystemProbe.swift   sysctl, VRAM total via system_profiler
  Report.swift        Markdown report with no identifiers
  IOKitProbe.swift    IORegistry helpers
  Shell.swift         Process helper

Sources/NullMothMonitorCLI/
  main.swift          summary / json / report / watch

Sources/NullMothMonitorApp/
  main.swift          NSStatusItem + NSPopover + AppDelegate
  MonitorStore.swift  timer, background sampling, history
  MonitorView.swift   SwiftUI popover
  Sparkline.swift     utilization history

Tests/NullMothCoreTests/
  SystemProbeTests.swift
  DriverProbeTests.swift
  MetalProbeTests.swift
  GPUProbeTests.swift
  ReportTests.swift

Scripts/
  GenerateIcon.swift  deterministic 1024×1024 icon renderer
  make-icon.sh        iconset → AppIcon.icns

Support/
  Info.plist          LSUIElement app metadata
  AppIcon.png         icon source
  AppIcon.icns        bundled icon
```

Data flow:

```
Timer (1 Hz, main)
  → MonitorStore.refresh()
    → serial probe queue
      → MonitorProbe.snapshot()
        → GPUProbe / DisplayProbe / AudioProbe / DriverProbe / SystemProbe / SMCProbe
    → main queue: publish snapshot, append history, update status item
```

## 5. Data sources and exact keys

### GPU

`NVAccel` IORegistry properties:

- `PerformanceStatistics`:
  - `Device Utilization %`
  - `GPU Core Utilization %`
  - `GPU Memory Utilization %`
  - `GPU Video Engine Utilization %`
  - `GPU Video Decode Utilization %`
  - `Temperature(C)`
- `PerformanceStatisticsAccum`:
  - `inUseVidMemoryBytes`
  - `gartSizeBytes`
  - `gartUsedBytes`

`NVRM` IORegistry properties:

- `nvrm-kext-version` (e.g. `3.0`)
- `nvrm-bars` (e.g. `bar0@0x10:... bar1@0x14:... bar2@0x1c:...`)

Metal:

- `MTLCopyAllDevices()` → first device whose name contains `NVIDIA`
- `supportsFamily(.metal4/.metal3)` for the family label
- `supportsRaytracing`
- `recommendedMaxWorkingSetSize`

VRAM total:

- `/usr/sbin/system_profiler SPDisplaysDataType -json` →
  `SPDisplaysDataType[].spdisplays_vram` (e.g. `12 GB`), parsed and cached.

### Displays

- `CGGetOnlineDisplayList`
- `CGDisplayCopyDisplayMode` → `pixelWidth`, `pixelHeight`, `refreshRate`
- `NSScreen.screens` → `localizedName`, keyed by `NSScreenNumber`

### Audio

- `kAudioHardwarePropertyDevices`
- `kAudioObjectPropertyManufacturer`
- `kAudioDevicePropertyDeviceNameCFString`
- `kAudioDevicePropertyStreamConfiguration` on the output scope
- `kAudioHardwarePropertyDefaultOutputDevice`

### Driver

- `/usr/bin/kmutil showloaded` → regex for `com.nullmoth.*` and version
- `/usr/sbin/nvram boot-args`
- `/usr/bin/csrutil status`
- `/Library/GPUBundles/NVMTLDriver.bundle` → `CFBundleShortVersionString`

### Fans

- `AppleSMC` via `IOConnectCallStructMethod`
- `FNum` for count, `F<n>Ac` for RPM
- Supports `flt `, `fpe2`, `ui8 `, `ui16`
- Returns `[]` when the SMC does not expose the keys

## 6. Design decisions

- **Native Swift + AppKit + SwiftUI.** `NSStatusItem` plus an `NSPopover` is the
  most reliable menu bar pattern from a SwiftPM executable. SwiftUI-only menu
  bar APIs were less predictable.
- **Read-only first.** Writing EFI or NVRAM is the fastest way to break a
  Hackintosh. Diagnostics are useful without that risk.
- **No installer features.** Avoid duplicating 1401. Monitoring and report export
  are the differentiators.
- **Menu bar, not a window.** GPU stats are glanceable; a full window is heavier
  than the job needs.
- **MIT license.** Keeps the tool clearly separate from the driver's PolyForm
  Noncommercial license. No driver code or firmware is included.
- **Optional fans.** Many desktop boards expose no SMC fan keys. The UI hides the
  Fans card when the list is empty.
- **Tolerant boot-argument checks.** Require `nvfb=1` and `nvaccel=1`, accept any
  of `amfi_get_out_of_my_way=0x1`, `amfi=0x80`, or `-amfipassbeta`, and flag
  `nv_disable=1` / `-wegnoegpu`. Machine-specific args such as `nvfbheads` and
  `-nvkmsnosmooth` are shown but not required.
- **Background sampling.** Probes run on a serial utility queue so the popover
  stays responsive, especially while `system_profiler` and `kmutil` run.
- **Privacy.** Reports are built from an allow-list of fields. They exclude
  serial numbers, UUIDs, EDIDs, and user paths.

## 7. Known limitations and gotchas

- GPU utilization is integer percent at 1 Hz. Sub-second spikes are smoothed.
- The driver does not expose per-process GPU usage, clocks, power draw, or fan
  control. Do not invent those numbers.
- VRAM total comes from `system_profiler`, which is slow on first read and is
  cached for the process lifetime.
- The Metal device name is decorated by the translator, e.g.
  `NVMTL over NVIDIA GeForce RTX 3060 (NVK GA106-A)`. `MetalProbe.cleanedName`
  strips the decoration.
- `.metal4` is compiled only with Swift 6.2+ (`#if compiler(>=6.2)`), so CI on
  older Xcode reports Metal 3 at most. Release builds should use Xcode 26+.
- The driver writes log lines to stderr. JSON on stdout stays clean; always
  redirect stderr when scripting.
- Fan RPM depends entirely on the SMC. An empty result is normal and is not a
  bug.
- `SecureBootModel` is always `nil` because it is an OpenCore config value, not
  readable at runtime.
- Only the first NVIDIA Metal device is reported. Multi-GPU is out of scope for
  now.
- The app is ad-hoc signed. On another Mac, Gatekeeper may require right-click →
  Open. Notarization needs a Developer ID and is a roadmap item.
- macOS 27 drops Intel support. The target range is macOS 14–26.
- The app is `LSUIElement`; it has no Dock icon by design.
- **Release architecture.** GitHub's `macos-15` runner is arm64. A plain
  `make app` there produces an arm64-only bundle that Intel Hackintoshes reject
  with “this application is not supported on this Mac.” Always release with
  `make app-universal`, which cross-compiles both slices and combines them with
  `lipo`. CI and the release workflow verify `x86_64 arm64`.
- `v0.1.0` shipped arm64-only and is broken on Intel. `v0.1.1` is the universal
  fix.

## 8. Roadmap

Prioritized; pick the top unchecked item unless the user asks otherwise.

### P0 — publish

- [x] Push to GitHub and confirm CI is green.
- [x] Tag `v0.1.0` and verify the release workflow (arm64-only; superseded).
- [ ] Tag `v0.1.1` and verify the universal release.
- [ ] Add a screenshot or short GIF to the README.
- [ ] Add repository topics and description.

### P1 — high-value polish

- [ ] Refresh immediately on display reconfiguration
  (`CGDisplayRegisterReconfigurationCallback`).
- [ ] Add a °C/°F preference (persisted with `UserDefaults`; no network).
- [ ] Add an `--watch --json` NDJSON mode for scripting.
- [ ] Add "Save report…" with `NSSavePanel` in addition to copy.
- [ ] Show the driver's BAR sizes in the UI (currently report-only).

### P2 — useful extensions

- [ ] Menu bar display style options: utilization only, temperature only, both.
- [ ] Launch-at-login toggle via `SMAppService` (no helper, no network).
- [ ] Detect GPU model and compare against the driver's supported-card list,
  without downloading anything at runtime.
- [ ] Add a compact "driver health" summary badge in the popover header.
- [ ] Add a `--once` alias and shell completion examples.

### P3 — distribution

- [ ] Developer ID signing and notarization (`notarytool`, stapling).
- [ ] Homebrew cask.
- [ ] Sparkle-style updates are **not** planned; no network access is a feature.
- [ ] Localization (English first).

### Explicit non-goals

- Installing, updating, rolling back, or uninstalling the driver.
- Uploading logs or reports automatically.
- Fan control, overclocking, or voltage changes.
- Writing NVRAM, EFI, kexts, or SIP state.
- Per-process GPU attribution unless the driver starts exposing it.

## 9. Publishing checklist

See [PUBLISHING.md](PUBLISHING.md) for exact commands. Summary:

1. Create `OWNER/nullmoth-monitor` on GitHub.
2. Push the default branch (`master` in this repository).
3. Confirm the CI workflow passes.
4. Tag `v0.1.1`; the release workflow builds a universal app, verifies both
   architectures, and attaches the app zip, universal CLI, and SHA-256 file.
5. Add a repository description and topics:
   `hackintosh`, `nvidia`, `macos`, `swift`, `menubar`, `gpu-monitor`.
6. Enable private vulnerability reporting.
7. Optionally add a social preview using `Support/AppIcon.png`.
8. Optionally notarize for wider distribution.

## 10. Verification checklist for the next agent

Run these before and after changes:

```sh
swift --version
swift test
swift build -c release
.build/release/nullmoth-mon
.build/release/nullmoth-mon --json 2>/dev/null | python3 -m json.tool >/dev/null && echo JSON_OK
.build/release/nullmoth-mon --report 2>/dev/null | head -40
make app-universal
lipo -archs "build/NullMoth Monitor.app/Contents/MacOS/NullMothMonitor"
# expected: x86_64 arm64
codesign --verify --deep --strict "build/NullMoth Monitor.app"
open "build/NullMoth Monitor.app"
```

Then confirm:

- The menu bar shows `GPU <n>% · <t>°`.
- The popover shows GPU, Displays, Audio, and Driver sections.
- The Fans card is absent on this machine (expected).
- Right-click offers refresh, copy report, and quit.
- `git status` is clean after committing.

## 11. Recent commits

Use `git log --oneline` for the authoritative list. At handoff time:

```
b2c6f6a Add app icon, CI workflows, and publishing docs
7a5b394 Show fan RPM when available and add pause control
dbce470 Polish driver checks and menu bar sampling
3b77d8e Add NullMoth Monitor menu bar app and CLI
```

A local annotated tag `v0.1.1` should point at the release commit. Push it only
when you are ready for the release workflow to run.

Published tags:

- `v0.1.0` — initial release; arm64-only, broken on Intel.
- `v0.1.1` — universal build fix.

## 12. License boundaries

- This repository: MIT. See [LICENSE](../LICENSE).
- NullMoth driver, kexts, Metal plugin, and packaging: PolyForm Noncommercial
  1.0.0 and other upstream licenses. They are **not** included here.
- Do not copy driver source, binaries, firmware, or assets into this repo.
- Do not describe this tool as official or endorsed by NullMoth.

## 13. Ownership and contact

No maintainer is recorded yet. When publishing, add the repository owner to the
README and SECURITY.md so reports reach the right person.
