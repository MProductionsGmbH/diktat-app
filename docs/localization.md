# Languages

Diktat for Mac speaks German and English. The app follows the language of macOS: with a German
system it shows German, with an English one English, and any other language falls back to German.

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
