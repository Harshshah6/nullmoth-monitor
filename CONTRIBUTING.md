# Contributing

Thanks for helping improve NullMoth Monitor.

## Ground rules

- **Read-only system state.** Never add code that writes EFI, OpenCore config,
  kexts, NVRAM, SIP, or system settings. No privileged helpers. Applying a
  display mode the user picked is allowed: it needs no rights and is a session
  setting.
- **No driver redistribution.** Do not vendor NullMoth kexts, the Metal plugin,
  firmware, or Apple binaries. Do not install or update the driver.
- **No telemetry.** No analytics, crash reporting, or auto-update. The only
  network request is the driver update check, which the user starts and which
  downloads nothing.
- **Privacy.** Reports must exclude serial numbers, UUIDs, EDIDs, and user paths.
- **No affiliation claims.** Keep the "not affiliated with NullMoth" disclaimer.
- **Graceful degradation.** The app must work without the driver.

## Setup

Requirements: macOS 14+, Xcode command line tools with Swift 5.9+.

```sh
git clone <your-fork>
cd nullmoth-monitor
swift build
swift test
make app              # host architecture
make app-universal    # both architectures, for release checks
open "build/NullMoth Monitor.app"
```

Xcode 26+ is recommended for local release builds, but not required: Metal 4 is
detected at runtime through the `MTLGPUFamily` raw value.

## Testing

- Run `swift test` before opening a pull request.
- Add pure parser tests for any new text or registry parsing.
- Do not require the NullMoth driver for tests. Tests must pass on a stock Mac.
- If you can, verify the UI on real Hackintosh hardware and include the output of
  `nullmoth-mon --report` (redact anything personal).

## Adding a probe

1. Add a `Codable` model in `Sources/NullMothCore/Models.swift`.
2. Add a probe `enum` that returns the model. Keep it read-only.
3. Wire it into `MonitorSnapshot` and `MonitorProbe.snapshot()`.
4. Render it in `MonitorView.swift` only when data exists.
5. Include it in `Report.swift` if it helps bug reports.
6. Cache expensive subprocess work. The app samples at 1 Hz.
7. Add a parser test and run `swift test`.

## Pull request checklist

- [ ] The change is read-only and adds no network access beyond the explicit
      update check.
- [ ] `swift test` passes.
- [ ] `make app` succeeds and the app launches.
- [ ] Release-affecting changes keep `make app-universal` working
      (`lipo -archs` reports `x86_64 arm64`).
- [ ] New parsers have tests.
- [ ] Reports still contain no identifiers.
- [ ] README or HANDOFF updated if behavior changed.
- [ ] Commit messages are imperative and scoped.

## Commit style

Short imperative subject, for example:

```
Add display hotplug refresh
Fix VRAM parsing for fractional GB values
```

Use a body only when the reason is not obvious.

## License

By contributing, you agree that your contribution is licensed under the MIT
license in [LICENSE](LICENSE). Do not contribute code you cannot license this way.
