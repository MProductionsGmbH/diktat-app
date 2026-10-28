**Diktat for Mac**: speak, and the text appears at your cursor. Speech recognition runs on your Mac.

## Install

1. Download **Diktat.dmg**, open it and drag Diktat onto the Applications folder.
2. Open Diktat from Applications. macOS says it cannot check the app for malicious software, because this version is not notarized yet. Press **Done**, then open **System Settings > Privacy & Security**, scroll down and press **Open Anyway** next to Diktat (German: Systemeinstellungen > Datenschutz & Sicherheit > Trotzdem öffnen). Do not press "Move to Trash".
3. Allow the microphone and, to paste directly into other apps, **Accessibility**.
4. Choose a speech model and load it. Whisper Large v3 Turbo is about 630 MB, once.

Prefer the Terminal? This installs it without the macOS warning:

```bash
curl -fsSL -o /tmp/Diktat.zip https://github.com/MProductionsGmbH/diktat-app/releases/latest/download/Diktat.zip && ditto -x -k /tmp/Diktat.zip /Applications && open /Applications/Diktat.app
```

## Requirements

macOS 14 or newer. Apple Intelligence (macOS 26) or a local model server such as Ollama is needed for the cleanup levels Medium, Strong and written style.

The `SHA256SUMS.txt` file lets you check the download.
