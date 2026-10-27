# Privacy

Diktat has no backend. It does not collect, send or store any data on servers operated by Diktat or MProductions GmbH.

## What Stays On Your Mac

- **Audio:** recorded and transcribed on your Mac with a local model (Parakeet or Whisper). Temporary recordings are deleted after each workflow.
- **Writing modes with Apple Intelligence:** run on your Mac.
- **Settings, dictionary, prompts:** local app storage.
- **History (optional):** encrypted on your Mac, kept as long as you choose (off, 24 hours, 7 days).
- **API keys** for an optional model provider: in the macOS Keychain.
- **Text around the cursor:** when a dictation starts, Diktat reads the focused text field through the Accessibility API to fit spaces and capitals. Password fields are never read. The text stays on your Mac, unless you turn on "KI-Modi sehen den Text am Cursor" (see below).
- **Meetings:** the microphone and, for online meetings, the sound your Mac plays are recorded and transcribed on your Mac; speaker detection runs there too. The audio is deleted after the evaluation; transcript and summary are stored encrypted on your Mac. Live notes and the summary use only the local language model, Apple Intelligence or a model server on this Mac itself (Ollama or LM Studio on `localhost`, `127.0.0.1` or `::1`), whatever is set for the writing modes. They never use a server elsewhere in the network, a model provider on the internet or a remote address, even if you entered one as your provider. With a server on this Mac the transcript goes to that program on your Mac and stays there; it is as private as the program you run. Set Ollama's context length to at least 16,384 (`OLLAMA_CONTEXT_LENGTH`), otherwise it may read only the start of a long part.
- **Browser address:** only if you added a website to "Modus je App", Diktat reads the address of the frontmost browser tab when you press the Diktat shortcut, to pick the mode. It stays on your Mac.

## When Data Leaves Your Mac

- **Model download:** loading a speech model, or the optional local language model for meetings, downloads it from Hugging Face (huggingface.co). Hugging Face sees the request, as with any download.
- **Optional model provider:** if you add your own provider and API key, the *recognized text* of the writing modes goes directly from your Mac to that provider. Audio never does. Your contract and their privacy terms apply.
- **"Versprecher glätten" (Mittel, Stark):** the recognized text of word-for-word dictation goes through the same model as the writing modes: Apple Intelligence on your Mac, or your own provider. A local server (Ollama, LM Studio on this Mac) keeps it on your Mac. "Leicht" never uses a model.
- **Text around the cursor for the writing modes (off by default):** with "KI-Modi sehen den Text am Cursor" on, the text around your cursor goes along to the writing mode. With Apple Intelligence it stays on your Mac; with your own model provider it goes to that provider.
- **Update check:** Diktat asks the GitHub releases of this repository for a new version (Sparkle). GitHub sees the request, as with any download. Turn it off in Settings > Allgemein > Über Diktat. On Macs managed by Jamf, Diktat does not check; updates come from the device management.

## Clipboard

To paste, Diktat puts the text on the clipboard and restores your previous clipboard afterwards. Clipboard managers may still see the text while it is there.

## Sensitive Content

Transcription and the Apple Intelligence modes are local. If you configure an external model provider, check whether your content may be sent there.
