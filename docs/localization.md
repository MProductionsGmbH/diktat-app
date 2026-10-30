# Languages

Diktat for Mac speaks German and English. Settings > Allgemein > Sprache has two separate choices.

**Sprache der App:** Automatisch (the app follows macOS: German with a German system, English with an
English one, any other language falls back to German), Deutsch or English. The choice is stored as the
app's own `AppleLanguages` default and applies after a restart (a button restarts the app).

**Diktiersprache:** Automatisch (default: the speech models detect the language for every dictation),
Deutsch or English (Whisper listens for that language only, and the cleanup, AI modes and filler words
use it). It does not change the language of the app.

## Dictation

The speech models detect the spoken language themselves. The steps after them follow what was
said, not the system language: the cleanup levels, AI writing style, WTF and :-) use German
instructions for a German dictation and English ones for everything else (`PromptLanguage`,
`ModePrompts`, `SpeechCleanup`). Filler words ("äh", "um", "uh") are taken out per language.

## Texts of the app

The texts in the code are written in German and are the keys of `DiktatMac/Resources/Localizable.xcstrings`;
the English version is stored there. `InfoPlist.xcstrings` holds the permission texts.

- In SwiftUI, `Text("…")`, `Button("…")`, `Toggle("…")` and the like look the text up by themselves.
- Everywhere else (messages, enums, strings that are passed around) write `String(localized: "…")`.
- A new text needs its English entry in the catalog. Xcode adds the missing keys when you build in
  the IDE; fill in the English value, and keep placeholders (`%@`, `%lld`) the same.
- Do not translate text that goes to a language model, file names, keys or log lines.
- Dates and numbers use `AppLocale.current`, so they match the language of the texts.
