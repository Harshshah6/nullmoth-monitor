# AGENTS.md

Instructions for AI coding agents working in this repository.

## Start here

1. Read [`HANDOFF.md`](HANDOFF.md) for project state, hardware notes, and the roadmap.
2. Run `swift test` before changing code.
3. Keep every change read-only and local.

## Mission

NullMoth Monitor is a native macOS menu bar app and CLI that shows what the
NullMoth NVIDIA driver exposes on a Hackintosh: GPU utilization, temperature,
VRAM, displays, HDMI/DP audio, kext state, boot arguments, and optional fan RPM.

It is a **companion**, not an installer. The 1401 app already handles install,
update, rollback, and log upload.

## Non-negotiable rules

- **Read-only.** Never write EFI, OpenCore config, kexts, NVRAM, SIP, or system
  settings. Do not add a privileged helper.
- **No driver redistribution.** Never vendor or download NullMoth kexts,
  `NVMTLDriver.bundle`, firmware, or Apple binaries.
- **No telemetry or network.** No analytics, crash reporting, auto-update, or
  HTTP calls.
- **No affiliation.** Do not imply NullMoth endorses this project. Keep the
  disclaimer visible.
- **Privacy.** Reports must exclude serial numbers, UUIDs, EDIDs, and user paths.
- **Graceful degradation.** The app must work without the driver, showing
  whatever is available.

## Commands

```sh
swift build                 # debug build
swift test                  # 31 tests, no driver required
make app                    # release .app in build/
make run                    # build + open
.build/debug/nullmoth-mon   # CLI summary
.build/debug/nullmoth-mon --json
.build/debug/nullmoth-mon --report
make icon                   # regenerate Support/AppIcon.icns
```

Driver log lines go to stderr. When piping JSON, use `2>/dev/null`.

## Architecture

| Path | Role |
|---|---|
| `Sources/NullMothCore/Models.swift` | Codable snapshot models |
| `Sources/NullMothCore/MonitorProbe.swift` | Single snapshot entry point |
| `Sources/NullMothCore/GPUProbe.swift` | `NVAccel` / `NVRM` + Metal |
| `Sources/NullMothCore/DisplayProbe.swift` | CoreGraphics + `NSScreen` |
| `Sources/NullMothCore/AudioProbe.swift` | CoreAudio |
| `Sources/NullMothCore/DriverProbe.swift` | kexts, boot args, SIP, plugin |
| `Sources/NullMothCore/SMCProbe.swift` | optional fan RPM |
| `Sources/NullMothCore/SystemProbe.swift` | sysctl + VRAM total |
| `Sources/NullMothCore/Report.swift` | redacted Markdown report |
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
7. Run `swift test` and `make app`.

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
- `.metal4` is behind `#if compiler(>=6.2)` so older SDKs still build.
- `system_profiler` is slow; it is cached after the first read.
- Boot arguments vary; only require `nvfb=1`, `nvaccel=1`, and one AMFI bypass.
- The app is `LSUIElement` (menu bar only) and ad-hoc signed.
- macOS 27 drops Intel; target macOS 14–26.

## Do not

- Add install, update, rollback, or log-upload features.
- Add a privileged helper or shell out to destructive commands.
- Add network access or third-party dependencies without a strong reason.
- Store history on disk or collect identifiers.
- Claim the driver is safe, official, or supported by NullMoth.

## Handoff

See [`HANDOFF.md`](HANDOFF.md) for current status, validation results, roadmap,
and publishing steps.
