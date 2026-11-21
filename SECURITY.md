# Security policy

## Supported versions

Only the latest release is supported. The project is pre-1.0, so fixes land on
`main` and in the next tag.

## Reporting a vulnerability

Please use GitHub's **private vulnerability reporting** on the repository
(Security → Advisories → Report a vulnerability). Do not open a public issue for
a security problem.

If private reporting is unavailable, contact the maintainer listed in the
repository profile.

## Scope

NullMoth Monitor is a read-only, local-only diagnostic tool. In scope:

- Code execution or privilege escalation caused by parsing untrusted input.
- Path traversal or file writes outside the app's own bundle.
- Leakage of identifiers (serial numbers, UUIDs, EDIDs, user paths) in reports.
- Any accidental network request or telemetry.
- Crashes caused by malformed IOKit, SMC, CoreAudio, or display data.

Out of scope:

- The NullMoth driver itself. Report driver issues to the driver project.
- Gatekeeper warnings on ad-hoc signed builds. The release is not notarized yet.
- Missing fan sensors or other data the driver/SMC does not expose.
- macOS 27 and later, where Intel support is removed.

## Design guarantees

- The app and CLI never write EFI, OpenCore config, kexts, NVRAM, SIP, or system
  settings.
- There is no privileged helper.
- There are no network requests.
- Reports are built from an allow-list of fields and exclude serial numbers,
  UUIDs, EDIDs, and user paths.

If you find code that violates any of these, treat it as a security issue.

## What to include

- macOS version and build.
- GPU model and driver version (`nullmoth-mon --report` is useful; redact
  anything personal).
- Steps to reproduce.
- The smallest relevant log excerpt. The driver logs to stderr.

## Response

This is a volunteer project. Reports are acknowledged on a best-effort basis,
typically within a week. Please allow time for a fix before public disclosure.
