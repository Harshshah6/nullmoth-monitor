# Publishing

Step-by-step instructions for putting this repository on GitHub and cutting the
first release. Replace `OWNER` with your GitHub user or organization.

## Prerequisites

- Git and the GitHub CLI (`gh`) installed and authenticated (`gh auth login`).
- A clean working tree: `git status`.
- A passing test run: `swift test`.

## 1. Create the repository

From the project root:

```sh
gh repo create OWNER/nullmoth-monitor \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "Read-only menu bar monitor for the NullMoth NVIDIA driver on Hackintosh"
```

If you prefer the web UI, create an empty repository and then:

```sh
git remote add origin git@github.com:OWNER/nullmoth-monitor.git
git push -u origin HEAD
```

## 2. Configure the repository

```sh
gh repo edit OWNER/nullmoth-monitor \
  --add-topic hackintosh \
  --add-topic nvidia \
  --add-topic macos \
  --add-topic swift \
  --add-topic menubar \
  --add-topic gpu-monitor \
  --enable-discussions=false
```

Recommended settings:

- Enable **private vulnerability reporting** (Settings → Code security).
- Confirm **Actions** is enabled.
- Add a social preview using `Support/AppIcon.png` (Settings → General).
- Pin the repository description and website if you have one.

## 3. Verify CI

The `CI` workflow runs on every push to the default branch (`main` or `master`)
and on pull requests:

```sh
gh run list --workflow ci.yml
gh run watch
```

It builds both architecture slices in release mode, runs `swift test`, bundles a
universal app, verifies `x86_64` and `arm64` are present, checks the signature,
and uploads `NullMothMonitor.zip` as an artifact.

> **Why universal matters.** GitHub's `macos-15` runners are Apple Silicon. A
> plain `make app` there produces an arm64-only bundle, and Intel Hackintoshes
> refuse it with “this application is not supported on this Mac.” This is exactly
> what happened to `v0.1.0`; `v0.1.1` fixed it with `make app-universal`.

## 4. Cut a release

```sh
git tag -a v0.2.0 -m "NullMoth Monitor 0.2.0"
git push origin v0.2.0
```

The `Release` workflow builds the universal app, stamps the version from the tag,
ad-hoc signs the bundle, packages the app zip, the universal `nullmoth-mon` CLI,
and a combined SHA-256 file, then creates a GitHub Release.

Verify:

```sh
gh release view v0.2.0
gh release download v0.2.0
shasum -a 256 -c SHA256SUMS-v0.2.0.txt
unzip -q NullMothMonitor-v0.2.0.zip -d /tmp/nullmoth-check
lipo -archs "/tmp/nullmoth-check/NullMoth Monitor.app/Contents/MacOS/NullMothMonitor"
# expected: x86_64 arm64
```

## 5. Optional: notarization

The release workflow produces an ad-hoc signed app. On other Macs, Gatekeeper may
require right-click → Open. For wider distribution, sign with a Developer ID and
notarize:

1. Add these repository secrets:
   - `MACOS_CERTIFICATE` (base64 `.p12`)
   - `MACOS_CERTIFICATE_PASSWORD`
   - `APPLE_ID`
   - `APPLE_TEAM_ID`
   - `APPLE_APP_PASSWORD` (app-specific password)
2. Import the certificate into a temporary keychain in the workflow.
3. Sign with `codesign --deep --force --options runtime --sign "Developer ID Application: ..."`.
4. Submit with `xcrun notarytool submit ... --wait`.
5. Staple with `xcrun stapler staple`.
6. Re-zip after stapling.

Do not commit certificates or passwords. Notarization is a roadmap item, not a
prerequisite for publishing source.

## 6. Post-publish checklist

- [ ] CI badge renders on the README (it uses a relative Actions URL).
- [ ] Release assets download and the checksum matches.
- [ ] `lipo -archs` on the downloaded app reports `x86_64 arm64`.
- [ ] `SECURITY.md` points to a real contact or advisory link.
- [ ] README says "not affiliated with NullMoth".
- [ ] LICENSE is MIT and no driver code is present.
- [ ] Issue templates appear under New Issue.
- [ ] Repository topics and description are set.
- [ ] The app icon appears in Finder and in the release zip.

## 7. If you need to undo a release

```sh
gh release delete v0.2.0 --yes
git push origin :refs/tags/v0.2.0
git tag -d v0.2.0
```

Then fix the issue, retag, and push again. Do not reuse a tag that already
produced a broken asset; bump the patch version instead.
