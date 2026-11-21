## Summary

## Testing

- [ ] `swift test`
- [ ] `make app` and launch the app
- [ ] `make app-universal` (release-affecting changes) and `lipo -archs` shows
      `x86_64 arm64`
- [ ] Verified on Hackintosh hardware (optional; describe the GPU and driver)

## Checklist

- [ ] Read-only: no EFI, OpenCore, kext, NVRAM, SIP, or system writes.
- [ ] No privileged helper.
- [ ] No network access or telemetry.
- [ ] Reports still exclude serial numbers, UUIDs, EDIDs, and user paths.
- [ ] New parsers have unit tests.
- [ ] Docs updated if behavior changed.
