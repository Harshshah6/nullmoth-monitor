# AGENTS.md

Instructions for AI coding agents working in this repository.

## Start here

1. Read [`docs/HANDOFF.md`](docs/HANDOFF.md) for project state, hardware notes, and the roadmap.
2. Run `swift test` before changing code.
3. Keep every change read-only and local.

## Mission

NullMoth Monitor is a native macOS menu bar app and CLI that shows what the
NullMoth NVIDIA driver exposes on a Hackintosh: GPU utilization, temperature,
VRAM, displays, HDMI/DP audio, kext state, boot arguments, and optional fan RPM.

It is a **companion**, not an installer. The 1401 app already handles install,
update, rollback, and log upload.

## Non-negotiable rules

- **Read-only system state.** Never write EFI, OpenCore config, kexts, NVRAM,
  SIP, or system settings. Do not add a privileged helper. The one exception is
  applying a display mode the user picked in the app, which is a session
  setting with no administrator rights.
- **No driver redistribution.** Never vendor or download NullMoth kexts,
  `NVMTLDriver.bundle`, firmware, or Apple binaries. Never install or update the
  driver; that is the 1401 app's job.
- **No telemetry.** No analytics, crash reporting, or auto-update. The only
  network request is the driver update check, which happens when the user asks
  for it, goes to `api.github.com`, and downloads nothing.
- **No affiliation.** Do not imply NullMoth endorses this project. Keep the
  disclaimer visible.
- **Privacy.** Reports must exclude serial numbers, UUIDs, EDIDs, and user paths.
- **Graceful degradation.** The app must work without the driver, showing
  whatever is available.

## Commands

```sh
swift build                 # debug build
swift test                  # 55 tests, no driver required
make app                    # release .app for this Mac's architecture
make app-universal          # release .app for x86_64 + arm64 (use for releases)
make run                    # build + open
.build/debug/nullmoth-mon   # CLI summary
.build/debug/nullmoth-mon --json
.build/debug/nullmoth-mon --report
.build/debug/nullmoth-mon --doctor
.build/debug/nullmoth-mon --modes
.build/debug/nullmoth-mon --capabilities
.build/debug/nullmoth-mon --check-update
make icon                   # regenerate Support/AppIcon.icns
```

Driver log lines go to stderr. When piping JSON, use `2>/dev/null`.

The app accepts `--show-monitor` and `--show-control` launch arguments to open
the popover on a specific tab, which makes screenshots and UI checks easier.

## Architecture

| Path | Role |
|---|---|
| `Sources/NullMothCore/Models.swift` | Codable snapshot models |
| `Sources/NullMothCore/MonitorProbe.swift` | Single snapshot entry point |
| `Sources/NullMothCore/GPUProbe.swift` | `NVAccel` / `NVRM` + Metal |
| `Sources/NullMothCore/DisplayProbe.swift` | CoreGraphics + `NSScreen` |
| `Sources/NullMothCore/DisplayModeProbe.swift` | Display mode list and apply |
| `Sources/NullMothCore/AudioProbe.swift` | CoreAudio |
| `Sources/NullMothCore/DriverProbe.swift` | kexts, boot args, SIP, plugin |
| `Sources/NullMothCore/DriverSettingsAudit.swift` | Setup audit against the docs |
| `Sources/NullMothCore/CapabilityProbe.swift` | Metal, VideoToolbox, OpenGL, firmware |
| `Sources/NullMothCore/UpdateChecker.swift` | Explicit GitHub release check |
| `Sources/NullMothCore/SMCProbe.swift` | optional fan RPM |
| `Sources/NullMothCore/SystemProbe.swift` | sysctl + VRAM total |
| `Sources/NullMothCore/Report.swift` | redacted Markdown report |
| `Sources/NullMothOpenGL/` | C shim for the deprecated OpenGL API |
| `Sources/NullMothMonitorCLI/main.swift` | CLI |
| `Sources/NullMothMonitorApp/` | menu bar app |
| `Tests/NullMothCoreTests/` | parser and report tests |

`MonitorProbe.snapshot()` must stay cheap enough for 1 Hz. Cache subprocess
probes; the app samples on a background queue.

## Adding a probe

1. Add a `Codable` model in `Models.swift` if the data is user-visible.
2. Add a probe `enum` in `NullMothCore` that returns the model.
3. Wire it into `MonitorSnapshot` and `MonitorProbe.snapshot()`.
4. Render it in `MonitorView.swift` only when data exists.
5. Include it in `Report.swift` if it helps bug reports.
6. Add a pure parser test if you parse text.
7. Run `swift test` and `make app-universal`.

The control panel has its own flow: `ControlStore` loads the display catalogs,
the settings audit, and the capabilities in the background, and
`ControlPanelView` renders them. Keep network calls inside
`UpdateChecker`, and keep them user initiated.

## Conventions

- Swift 5.9 tools version; macOS 14 deployment target.
- Four-space indentation in Swift. The Makefile uses tabs.
- Prefer small `enum` namespaces with `static` probes.
- Keep UI text short and factual; no marketing copy.
- Use `ByteCountFormatter` for memory and `%.0f` for percentages.
- Commit messages: imperative mood, short subject, body only when useful.

## Gotchas

- The driver writes logs to stderr; never let that leak into JSON stdout.
- Fan sensors are often absent on desktop boards; an empty Fans section is normal.
- Metal reports `NVMTL over ... (NVK ...)`; use `MetalProbe.cleanedName`.
- Metal 4 is detected at runtime through the `MTLGPUFamily` raw value `5002`,
  so older SDKs still build and newer OSes still report Metal 4.
- `system_profiler` is slow; it is cached after the first read.
- Boot arguments vary; only require `nvfb=1`, `nvaccel=1`, and one AMFI bypass.
- The setup audit is stricter than the quick check: it follows the driver's
  documented `boot-args` and `csr-active-config 0x0A43`.
- `csr-active-config` is read with `nvram -X` and stored little endian, so
  `430a0000` means `0x00000A43`.
- The app is `LSUIElement` (menu bar only) and ad-hoc signed.
- macOS 27 drops Intel; target macOS 14–26.
- **Never release with plain `make app`.** GitHub's `macos-15` runner is arm64,
  so that produces an arm64-only bundle that Intel Macs refuse to open. Release
  with `make app-universal` and check `lipo -archs` reports `x86_64 arm64`.

## Do not

- Add install, update, rollback, or log-upload features.
- Add a privileged helper or shell out to destructive commands.
- Add network access beyond the explicit update check, or third-party
  dependencies without a strong reason.
- Write OpenCore, NVRAM, kexts, or system settings.
- Store history on disk or collect identifiers.
- Claim the driver is safe, official, or supported by NullMoth.

## Handoff

See [`docs/HANDOFF.md`](docs/HANDOFF.md) for current status, validation results, roadmap,
and publishing steps.
