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
git push -u origin main
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

The `CI` workflow runs on every push to `main` and on pull requests:

```sh
gh run list --workflow ci.yml
gh run watch
```

It builds in release mode, runs `swift test`, bundles the app, verifies the
signature, and uploads `NullMothMonitor.zip` as an artifact.

## 4. Cut a release

```sh
git tag -a v0.1.0 -m "NullMoth Monitor 0.1.0"
git push origin v0.1.0
```

The `Release` workflow builds the app, stamps the version from the tag, ad-hoc
signs the bundle, packages a zip plus SHA-256, and creates a GitHub Release.

Verify:

```sh
gh release view v0.1.0
gh release download v0.1.0
shasum -a 256 -c NullMothMonitor-v0.1.0.zip.sha256
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
- [ ] `SECURITY.md` points to a real contact or advisory link.
- [ ] README says "not affiliated with NullMoth".
- [ ] LICENSE is MIT and no driver code is present.
- [ ] Issue templates appear under New Issue.
- [ ] Repository topics and description are set.
- [ ] The app icon appears in Finder and in the release zip.

## 7. If you need to undo a release

```sh
gh release delete v0.1.0 --yes
git push origin :refs/tags/v0.1.0
git tag -d v0.1.0
```

Then fix the issue, retag, and push again.
