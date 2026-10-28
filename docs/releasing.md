# Releasing a new version

A release is a tag. GitHub builds the app, packs it and publishes it; people who already have
Diktat get it through the update check in the app once the update feed is switched on.

## Every release

1. In `DiktatMac/project.yml` raise `MARKETING_VERSION` (for example `0.1.1`) and
   `CURRENT_PROJECT_VERSION` (a whole number that grows with every release).
2. Commit and push to `main`, wait for the CI run to turn green.
3. Tag and push:

   ```bash
   git tag -a v0.1.1 -m "Diktat 0.1.1" && git push origin v0.1.1
   ```

4. The **Release** workflow builds the app and publishes `Diktat.dmg`, `Diktat.zip`,
   `SHA256SUMS.txt` and, when the update key is stored, `appcast.xml`.

## Updates inside the app (Sparkle)

The app checks `SPARKLE_FEED_URL` for a newer version and installs it when the user agrees.
Updates are signed, so nobody can slip in a fake one.

- **Public key:** `SPARKLE_PUBLIC_ED_KEY` in `project.yml`. It is already set.
- **Private key:** made once with Sparkle's `generate_keys`. It never goes into the repository.
  Store it as the repository secret **`SPARKLE_PRIVATE_KEY`** (Settings > Secrets and variables >
  Actions) and keep a second copy in a password manager. Lose it, and installed apps can no longer
  be updated; they would need a fresh download.
- **Feed:** every release carries `appcast.xml`, and `SPARKLE_FEED_URL` in `project.yml` points at
  the one of the newest release. Installed apps look there; a newer version is offered in the app
  (Settings > Nach Updates suchen, and automatically in the background). The first version with the
  feed (0.1.2) has to be installed by hand once.

`releases/latest` points at the newest release that is **not** marked as a pre-release.

## Signing and notarization (no warning when opening)

Without an Apple Developer ID the app is signed ad hoc. When someone opens the downloaded app,
macOS says it cannot check it for malicious software, and after every update it asks for
Accessibility again. A Developer ID and notarization remove both. They need a paid
**Apple Developer Program** membership; the Release workflow does the rest once these
repository secrets are stored (Settings > Secrets and variables > Actions):

| Secret | What it is |
|---|---|
| `DEVELOPER_ID_CERT_P12` | The certificate "Developer ID Application" with its private key, exported from Keychain Access as a `.p12` file and turned into text with `base64 -i certificate.p12 \| pbcopy`. |
| `DEVELOPER_ID_CERT_PASSWORD` | The password chosen when exporting the `.p12`. |
| `APPLE_ID` | The Apple ID of the developer account. |
| `APPLE_TEAM_ID` | The ten-character team id, shown in the developer account under Membership. |
| `APPLE_APP_PASSWORD` | An app-specific password made at appleid.apple.com (Sign-In and Security). |

With the secrets the workflow signs the app with the hardened runtime (`build.sh` does it when
`DIKTAT_SIGN_IDENTITY` is set), sends it to Apple, waits for the result and staples the ticket
to the app before it makes the DMG. Without them it still publishes, signed ad hoc.

This path has not been run against a real account yet. The first notarization often needs a
round of fixes; `xcrun notarytool log <id>` names the files Apple objects to.

## Until then: opening the app

Tell people to open **System Settings > Privacy & Security**, scroll to the message about
Diktat and press **Open Anyway** (in German: Systemeinstellungen > Datenschutz & Sicherheit >
Trotzdem öffnen). Or install from the Terminal, which skips the check; the command is in the
README.
