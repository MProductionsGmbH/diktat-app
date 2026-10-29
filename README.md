<p align="center">
  <img src="docs/assets/icon.png" width="96" height="96" alt="Diktat app icon">
</p>

<h1 align="center">Diktat</h1>

<p align="center">
  <b>Speak. Text. Done.</b><br>
  Dictation for your Mac that runs entirely on your Mac.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple" alt="macOS 14 or newer">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2563EB" alt="MIT License"></a>
  <a href="https://github.com/MProductionsGmbH/diktat-app/actions/workflows/ci.yml"><img src="https://github.com/MProductionsGmbH/diktat-app/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center">
  <a href="https://github.com/MProductionsGmbH/diktat-app/releases/latest/download/Diktat.dmg"><b>Download Diktat for Mac</b></a>
  &nbsp;·&nbsp;
  <a href="#install"><b>Install</b></a>
  &nbsp;·&nbsp;
  <a href="#build-it-yourself">Build it yourself</a>
</p>

Hold a shortcut, speak, let go. Diktat turns your speech into text and pastes it where your cursor is. Speech recognition runs on your Mac, the writing modes use Apple Intelligence on your Mac. No account, no server, no audio leaving the device.

## Install

1. **[Download Diktat.dmg](https://github.com/MProductionsGmbH/diktat-app/releases/latest/download/Diktat.dmg)**, open it and drag Diktat onto the Applications folder.
2. Open Diktat. macOS warns that it cannot check the app, because this version is not notarized yet. Press **Done** (not "Move to Trash"), then open **System Settings > Privacy & Security** and press **Open Anyway** next to Diktat.
3. Allow the microphone and Accessibility, then load a speech model.

Or in the Terminal, without the macOS warning:

```bash
curl -fsSL -o /tmp/Diktat.zip https://github.com/MProductionsGmbH/diktat-app/releases/latest/download/Diktat.zip && ditto -x -k /tmp/Diktat.zip /Applications && open /Applications/Diktat.app
```

## Why Diktat?

- **Private:** your voice never leaves your Mac. No account, no backend, no telemetry.
- **Native:** a small menu bar app in Swift, made for macOS, fast on Apple silicon.
- **More than dictation:** four modes turn rough speech into clean text, a calm message or a message with emojis.
- **Free and open:** MIT licensed. Use it, learn from it, build on it.

## How It Works

1. **Hold** a shortcut, for example `fn + Shift`.
2. **Speak** in any language your model knows. A small lilac pill at the bottom of the screen shows that Diktat is listening.
3. **Let go.** Diktat transcribes on your Mac with Parakeet or Whisper.
4. **Done.** The text appears at your cursor, fitted to the text around it. Your clipboard is restored afterwards.

## Modes

| Mode | Shortcut | What happens |
|---|---|---|
| **Diktat** | `fn` (globe key) | Speech to text; the cleanup level (light, medium, strong, AI written style) and the tone are set in the app |
| **Diktat WTF** | `fn + Option` | Frustrated speech to a calm, effective message |
| **Diktat :-)** | `fn + Cmd` | Text with fitting emojis |

`fn + Shift` also starts Diktat. Keyboards without `fn`: set your own shortcut per mode in the settings.

## Features

- **Local speech recognition:** Parakeet Ultra (fast, 25 European languages) or OpenAI Whisper via WhisperKit (about 100 languages). Both detect the spoken language.
- **Local writing modes:** the KI-Schreibstil cleanup level, WTF and :-) run with Apple Intelligence on your Mac (macOS 26). Optionally bring your own model provider: OpenAI, Anthropic, Google Gemini, Mistral, OpenRouter, or a local server such as Ollama or LM Studio.
- **Smooths what you stumble over:** three levels. *Leicht* removes "um", stutters and phrases said twice without any model. *Mittel* also drops restarts and self-corrections, *Stark* also fixes grammar, word order and punctuation. Both use Apple Intelligence or a local server such as Ollama (Qwen3 works), so it runs offline.
- **Fits where you type:** spaces and capitals follow the text around your cursor, also mid-sentence. Password fields are never read.
- **Mode per app or website:** Gmail always in AI written style, Slack with emojis, everything else word for word.
- **See that it listens:** a small lilac pill at the bottom of the screen moves with your voice while Diktat records. Click it to stop. It never takes the focus, so the text still lands where you type. You can turn it off in the settings.
- **Last text at hand:** the menu bar window shows your last text as a message. One click copies it.
- **Sound off while recording:** a podcast or music is muted while you speak and back right after.
- **Meetings in the room and online:** record a conversation through the microphone, get the transcript by person (Person 1, Person 2, rename them) and, if you like, a summary with decisions and to-dos. For calls, "Online-Meeting" (beta) also records what your Mac plays, for example from Teams, Zoom or Meet: you are "Ich", the others are told apart by voice, and what your microphone picks up from the speakers is filtered out of your part. Live notes (beta) show topics, decisions and to-dos while the meeting runs. Everything runs on your Mac and the recordings are deleted afterwards. Apple Silicon only. Please ask everyone before you record.
- **Ollama for meetings (beta):** if you run Ollama or LM Studio on this Mac and enter its address (`http://localhost:11434/v1`) as your own provider, meetings can summarize with that model too. With "Immer Modell-Anbieter" it comes first; otherwise it is the fallback when Apple Intelligence is missing. Only a server on this Mac itself counts: meetings never go to another device or to the internet.
- **Local language model for meetings (beta):** download Gemma 4 in the settings (E4B from 16 GB of memory, 12B from 24 GB). It summarizes long meetings more exactly than Apple Intelligence, on your Mac.
- **Text lands in the right place:** if you click into another field while a writing mode still works, the text goes to the clipboard instead of the wrong field. After a writing mode, "Wortgenau statt ..." in the menu swaps in what you actually said.
- **Voice memos and WhatsApp voice messages:** drop an audio file on Diktat and get the text, optionally with paragraphs.
- **Dictionary:** names and terms spelled your way, fixed replacements ("n acht n" becomes "n8n").
- **History:** recent results, encrypted and stored only on your Mac.
- **Updates in the app:** Diktat offers new versions from this repository's releases, signed and notarized by Apple.
- **Feedback:** "Feedback senden" in the settings prepares a mail to the team with version and setup. You see everything before it goes out.

The app is in German for now.

## Install

There is no signed release yet. Build the app yourself, see [Build It Yourself](#build-it-yourself). Then:

1. Open Diktat. It lives in the menu bar.
2. Allow **Microphone** and **Accessibility** (needed to paste into other apps).
3. In the settings (**Modelle**), load a local speech model once. Parakeet Ultra is recommended on Apple silicon, about 630 MB.
4. Hold `fn + Shift`, speak, let go.

**Requirements:** macOS 14 or newer. Parakeet needs Apple silicon; Intel Macs use Whisper. The writing modes on the device need macOS 26 with Apple Intelligence turned on; without it, add your own model provider or use plain dictation.

## Privacy

```text
Speech recognition:  your Mac (Parakeet or Whisper, Core ML / Neural Engine)
Writing modes:       your Mac (Apple Intelligence)
                     or, if you add one, your own model provider with your own API key
Meetings:            your Mac (transcript, speakers, live notes, summary with
                     Apple Intelligence or the optional local model), never a
                     model provider
Model download:      Hugging Face, once per model
Update check:        GitHub releases of this repository (can be turned off)
```

Diktat has no backend and collects no data. Details in [docs/privacy.md](docs/privacy.md).

## Known Limitations

- **`fn` shortcuts** only work on Apple keyboards. Set your own shortcut for other keyboards.
- **Paste stops after an update or a rebuild:** in the settings under Allgemein, click "Freigabe zurücksetzen" and allow Diktat again. By hand: System Settings > Privacy & Security > Accessibility, remove the old Diktat entry, add the current app and restart it.
- **First dictation after a macOS update** can take a few minutes while macOS prepares the model for the Neural Engine. Diktat shows a hint; keep it running.
- **Whisper on silence** sometimes invents phrases like "Thank you." Diktat filters the known ones.
- **Macs managed with Jamf:** in-app updates are off on the whole Mac, also for a copy you installed yourself. There, your device management handles updates.
- **Online meetings (beta):** without headphones the microphone also hears the speakers. Diktat filters that echo out of your part; a short scrap can remain. Headphones give the cleanest result. macOS asks for "System Audio Recording" the first time.
- **Local language model (beta):** needs Apple Silicon and at least 16 GB of memory, the 12B model 24 GB. It uses about 5 to 7 GB while it summarizes and frees them afterwards.

More in [docs/setup.md](docs/setup.md) and [docs/local-models.md](docs/local-models.md).

## Build It Yourself

You need Xcode 26 or newer (for the Apple Intelligence APIs) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/MProductionsGmbH/diktat-app.git
cd diktat-app
./build.sh --install --run
```

`build.sh` creates an ad-hoc signed app for your own Mac. If you publish a fork, use your own bundle identifier, name and icon (see [TRADEMARKS.md](TRADEMARKS.md)) and sign it with your own Developer ID.

```text
DiktatMac/        macOS menu bar app (SwiftUI, AppKit)
  App/               app state and lifecycle
  Features/          workflows, menu bar, settings, audio files, release notes, recording pill
  Services/          recording, hotkeys, local transcription, paste, history, updates
  Views/             shared UI pieces
  Tests/             unit tests: post-processing, cursor fit, paragraphs, filters
DiktatShared/     code shared with the (not yet public) iOS app
  AI/                model providers, Apple Intelligence rewriting, mode prompts
  Audio/             audio file conversion
  Transcription/     Whisper call and filter for invented text
  Design/            design tokens, Public Sans, shapes (speech bubble, message, Diktat mark)
  Licenses/          bundled third-party licenses
build.sh             local build script
```

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md), and see [ROADMAP.md](ROADMAP.md) for what comes next.

## Acknowledgments

- **[FluidAudio](https://github.com/FluidInference/FluidAudio)**, **Moondream** and **NVIDIA** for Parakeet Ultra on Core ML
- **[WhisperKit](https://github.com/argmaxinc/argmax-oss-swift)** by Argmax and **OpenAI** for Whisper
- **[Sparkle](https://sparkle-project.org)** for updates
- **Google** for Gemma 4 and **[MLX](https://github.com/ml-explore/mlx-swift)** for running it on the Mac
- **The Blitztext project** (MIT) by its contributors, on which Diktat is based, see [Origin](#origin)

Full license texts: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), also inside the app (Settings > Allgemein > Über Diktat).

## Origin

Diktat started as a fork of [Blitztext](https://github.com/cmagnussen/blitztext-app) by Blackboat Internet GmbH and its contributors (MIT License). It is now an independent project by MProductions GmbH with its own name, icon and development. The original copyright notice stays in [LICENSE](LICENSE). Blitztext and Blackboat are not affiliated with this project.

## License

MIT License, see [LICENSE](LICENSE). Without warranty and without guaranteed support.

The Diktat name and icon belong to MProductions GmbH, see [TRADEMARKS.md](TRADEMARKS.md).

## Legal

Diktat is published by MProductions GmbH. Impressum and privacy notice: to be added before the first public release.

## Languages

Diktat for Mac is available in German and English and follows the language of macOS. Dictation works in German, English and the other languages the speech models support. See [docs/localization.md](docs/localization.md).
