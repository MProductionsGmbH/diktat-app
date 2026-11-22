# Releasing a new version

A release is built on the maintainer's Mac and uploaded to GitHub. GitHub stores the result (the
tag, the release and its files) and builds nothing: its Mac runners were rarely free, and a release
waited for hours. People who already have Diktat get the new version through the update check in
the app.

## Every release

1. In `DiktatMac/project.yml` raise `MARKETING_VERSION` (for example `0.1.15`) and
   `CURRENT_PROJECT_VERSION` (a whole number that grows with every release).
2. Commit and push to `main`.
3. Run `scripts/release.sh`.

The script stops at the first thing that is not right. In this order it:

- checks that `main` is clean and equal to GitHub's, that the version has no release yet and that
  the build number is greater than the one of the newest release (the update check compares the
  build number; one that did not grow is never offered),
- checks that the Developer ID certificate and the notarization credentials are there,
- runs the tests,
- builds the universal app and signs it with the hardened runtime (`build.sh --release`),
- checks that the update key in the keychain is the one `SPARKLE_PUBLIC_ED_KEY` names,
- sends the app to Apple, waits for the result and staples the ticket,
- packs `Diktat.dmg` and `Diktat.zip`, signs the zip for the update check and writes `appcast.xml`,
- creates the tag (`v0.1.15`) on the built commit and publishes the release with
  `Diktat.dmg`, `Diktat.zip`, `SHA256SUMS.txt` and `appcast.xml`.

`scripts/release.sh --check` runs only the checks. `scripts/release.sh --no-publish` does everything
but the upload and leaves the files in `dist/`.

### Once per Mac

| What | How |
|---|---|
| Certificate "Developer ID Application" | In the login keychain, with its private key. Xcode > Settings > Accounts > Manage Certificates creates it, or import the `.p12`. |
| Notarization credentials | `xcrun notarytool store-credentials diktat-notary --apple-id <Apple ID> --team-id <team id>`. It asks for an app-specific password made at appleid.apple.com (Sign-In and Security) and keeps it in the keychain. |
| Update key | Sparkle's private key in the login keychain (made by `generate_keys`, or imported with `generate_keys -f <file>`). |
| `gh` | Signed in (`gh auth login`) with write access to the repository. |
| XcodeGen | `brew install xcodegen` |

The first time, macOS asks whether `codesign` and Sparkle's tools may use the keys in the keychain.
Choose "Always Allow".

If the keychain does not accept the password in that dialog (its password can differ from the
login password after a reset), put the update key into a file instead:
`generate_keys -x ~/.config/diktat/sparkle-update-key`, then `chmod 600` the file. The script uses
that file when it exists and first checks that it belongs to `SPARKLE_PUBLIC_ED_KEY`. Anyone who
can read the file can sign updates for every installed app, so it stays on this Mac, out of
backups to shared places, and never in the repository.

### Fallback: building on GitHub

The **Release** workflow still exists for a day the Mac is not at hand. It no longer starts by
itself: start it in the Actions tab (Release > Run workflow). It builds the version in
`project.yml` if there is no release for it yet, and needs the repository secrets named below.

## Updates inside the app (Sparkle)

The app checks `SPARKLE_FEED_URL` for a newer version and installs it when the user agrees.
Updates are signed, so nobody can slip in a fake one.

- **Public key:** `SPARKLE_PUBLIC_ED_KEY` in `project.yml`. It is already set.
- **Private key:** made once with Sparkle's `generate_keys`. It never goes into the repository.
  It lives in the login keychain of the Mac that releases; keep a second copy in a password
  manager. Lose it, and installed apps can no longer be updated; they would need a fresh download.
  The fallback workflow reads it from the repository secret **`SPARKLE_PRIVATE_KEY`**.
- **Feed:** every release carries `appcast.xml`, and `SPARKLE_FEED_URL` in `project.yml` points at
  the one of the newest release. Installed apps look there; a newer version is offered in the app
  (Settings > Nach Updates suchen, and automatically in the background). The first version with the
  feed (0.1.2) has to be installed by hand once.

`releases/latest` points at the newest release that is **not** marked as a pre-release.

## Signing and notarization (no warning when opening)

The app is signed with an Apple Developer ID and notarized by Apple, so macOS opens the download
without a warning and keeps the Accessibility permission across updates. `scripts/release.sh`
refuses to publish anything else.

The first submissions of a new developer account can wait in Apple's queue for hours. Run
`xcrun notarytool history --keychain-profile diktat-notary` to see the state of a submission;
`xcrun notarytool log <id> --keychain-profile diktat-notary` names the files Apple objects to.

### Secrets of the fallback workflow

Only the workflow on GitHub needs these (Settings > Secrets and variables > Actions):

| Secret | What it is |
|---|---|
| `DEVELOPER_ID_CERT_P12` | The certificate "Developer ID Application" with its private key, exported from Keychain Access as a `.p12` file and turned into text with `base64 -i certificate.p12 \| pbcopy`. |
| `DEVELOPER_ID_CERT_PASSWORD` | The password chosen when exporting the `.p12`. |
| `APPLE_ID` | The Apple ID of the developer account. |
| `APPLE_TEAM_ID` | The ten-character team id, shown in the developer account under Membership. |
| `APPLE_APP_PASSWORD` | An app-specific password made at appleid.apple.com (Sign-In and Security). |
| `SPARKLE_PRIVATE_KEY` | The private update key. |
