# Kaede

[日本語](README.md)

A macOS app for writing Japanese and English together without switching input modes.
Type English and romaji in plain letters; Kaede turns them into mixed Japanese and English text and types it into the app you came from.

```
kyouhagoogledekensaku        → 今日は google で検索
pythonnobug                  → python の bug
sikasinoatoallyouneedislove  → しかしのあと all you need is love
thisisapen.                  → this is a pen.
```

Kaede is the author's personal tool.
Parts of it assume the author's setup, such as the Hammerspoon configuration described below.

## How it works

1. Press ⌃⌥K to open the form, and type English and romaji as they come, with or without spaces.
2. The converted text shows in the lower half of the form as you type.
3. Press ⌘↩ to type the converted text at the cursor of the previous app. Kaede sends key events and leaves the clipboard alone; line breaks go as Shift+Enter.

Conversion runs entirely on the Mac; nothing goes over the network.
Kaede finds the English parts with an English word list and the rules of romaji, and converts the Japanese parts with the [azooKey](https://github.com/azooKey/AzooKeyKanaKanjiConverter) kana-kanji converter.

How the text is put together:

- Spaces inside Japanese go; spaces between English words stay. English typed without spaces is split into words.
- One half-width space separates Japanese from English.
- Inside Japanese, `, . ? ! -` become 、。？！ー. The comma and period pair can be changed in the settings.
- A word that starts with a capital letter stays English (`Tokyo`, `We are`).

## Typing Japanese with another layout

Kaede also reads Japanese typed with the fingering of a layout such as Ebi.
The form takes keys on the Roman (QWERTY) input source, so Japanese typed in Ebi arrives as QWERTY letters (例えば as `jajsd/a`).
Kaede reads the keys both in QWERTY and through the layout in the settings, keeping English in QWERTY and reading Japanese through the layout, even when the fingering changes in the middle of a word typed without spaces.

```
watashinoiflsgjdhfkf;a       → 私の理想的には (watashino in QWERTY, the rest in Ebi)
pythonksbug                  → python の bug (python and bug in QWERTY English, ks as Ebi no)
```

Choose the layout in the settings: Ebi, Eucalyn, 大西 and Waddlier are built in, and a layout of your own can be written as three rows of ten characters over the QWERTY rows.
With none chosen, Kaede reads QWERTY only.

## Fixing a conversion

Press Tab to choose conversions, with the keys of an input method:

| Key | Action |
|---|---|
| ← → | Move to the previous or next phrase or English part |
| Shift+← → | Shrink or grow the phrase by one character |
| ↓ ↑, Space | Step through the candidates |
| 1–9 | Pick a numbered candidate and move on |
| Return, Tab | Keep the choices and go back to writing |
| Escape, Backspace | Cancel the choices made since Tab |

To turn a part Kaede made Japanese back into English, press ↑ right after Tab.
The candidate list ends with the typed letters split into English words (we are for `weare`).

## Requirements

- macOS 26
- Xcode (Swift 6.2 or later) and [just](https://github.com/casey/just)
- Accessibility permission, to type into other apps

When the form opens and the input source is not the Roman one, Kaede taps the left Command key.
It relies on the author's Hammerspoon setup: a lone left Command selects Roman, and a lone right Command selects azooKey.

## Building

```sh
just test      # run the tests
just bundle    # build dist/Kaede.app
just run       # build and launch
```

`just bundle` signs the app with a certificate named "Kaede Code Signing".
Signing with the same certificate keeps the Accessibility permission across rebuilds.
Without it, `just signing_identity=- bundle` signs ad hoc, and the permission has to be granted again after each build.

## Settings

Open them from the leaf in the menu bar or the gear in the form.
They hold the keys that open the form and insert its text, the font size, the Japanese comma and period, the layout Japanese is typed with, and launching at login.

## License

Kaede's code is under the [MIT License](LICENSE).

`Resources/en10k.txt` is not covered by Kaede's license.
It is `google-10000-english-no-swears.txt` from [google-10000-english](https://github.com/first20hours/google-10000-english), unchanged.
The list derives from the Google Web Trillion Word Corpus; its distributor permits educational, personal and research use, and recommends licensing from the Linguistic Data Consortium for commercial use.

Fetched when building:

- [AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter) (MIT License). Its dictionary, azooKey_dictionary_storage, which `just bundle` copies into the app, is under the Apache License 2.0.

## Inspiration

- [Meltype](https://github.com/yksr-melt/Meltype): keeping English words in English while typing Japanese
- [Nospace](https://nospace.ryotarai.dev/): typing in a form, converting, and putting the text back into the app
- [azooKey](https://github.com/azooKey/azooKey-Desktop): the keys for choosing conversions

Kaede uses no code from any of them.
