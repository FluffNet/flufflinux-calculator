# Translating Calculator

Calculator follows the language selected in KDE Plasma. English is the source language. `translations/languages.tsv` defines the shared 96 language/script choices, and `translations/regions.tsv` contains their 172 country locales. `translations/LANGUAGES` lists 95 language/script catalogs plus two regional wording catalogs (`de_CH` and `pt_BR`). Translation files are stored in the `translations` folder.

## Edit an existing language

Install Qt 6 translation tools. On Arch Linux and Fluff Linux they are included with Qt 6 Tools.

Open the desired `.ts` file with Qt Linguist. For example:

```sh
linguist translations/flufflinux-calculator_de.ts
```

Translate each source message, mark it finished, and save the file. Preserve mathematical notation such as `sin(30) = 0.5`, literal example digits, and `%1` placeholders. Keep direction isolates around math examples in right to left text. Then rebuild and validate all catalogs:

```sh
make translations
make check-translations
```

## Add a language

Update the shared language inventory first, then add its language/script row to `translations/languages.tsv`, country rows to `translations/regions.tsv`, and desktop locale aliases. Add the compiled catalog to `translations/LANGUAGES` with its locale code and English name. Keep the inventory counts and RTL checks in `scripts/check-translations.py` in sync. Then run:

```sh
make update-translations
```

Open the new `.ts` file in Qt Linguist, complete it, and run the validation command.
The update command also adds the compiled catalog to the application resources.

Arabic, Hebrew, Persian, Urdu, Pashto, Uyghur, and Punjabi Shahmukhi include native right to left layout mirroring. Mathematical expressions, digits, bits, and operators remain left to right. Review both the translated text and the layout when updating these languages.

## Test one language

Set the language for one launch:

```sh
LANGUAGE=de ./target/release/flufflinux-calculator
```

Also test the Plasma language setting because the application follows the ordered language list in `plasma-localerc`.

Check Basic, Advanced, Financial, Programming, Conversion, Preferences, About, History, every menu, and every tooltip. Long text must wrap or shrink without being cut off.

Test at the minimum width for every mode. Open Preferences and About. In Programming, test both the keypad and bits, open both operation menus, and open History. In Conversion, open both unit lists. Every sentence must remain visible. Scrollable areas must expose all of their content.

## Regional and script selection

Calculator follows the desktop language selection; it does not change system locale files. The Rust resolver considers LANGUAGE, KDE's plasma-localerc translation setting, the original LC_ALL/LC_MESSAGES/LANG identifier, and Qt UI languages. Regional choices retain their base language. Chinese Simplified/Traditional, Serbian Latin/Cyrillic, and Punjabi Gurmukhi/Shahmukhi use distinct catalogs and never fall back across scripts. Valencian preserves the @valencia modifier, and Serbian Latin preserves @latin. An explicit English choice stops later language fallbacks.

Swiss German uses ss in place of ß. Brazilian Portuguese has a separate editable wording catalog. Other countries share their language's UI wording. Desktop names also include locale aliases for the regional and script identifiers.

## Draft status

The added language catalogs are editable translation drafts. Most initial drafts were machine-assisted using the calculator's public English source strings, with technical terms, project names, and placeholders checked and repaired. Norwegian Nynorsk was adapted from the existing Norwegian catalog, and Serbian Latin was transliterated from the existing Cyrillic catalog. Successful catalog, script, runtime, and layout checks do not imply native-speaker validation. Review wording in Qt Linguist when refining a language.

The application embeds its catalogs and uses system fonts. It needs no translation service or network connection at runtime. Noto fonts and Noto CJK fonts provide broad glyph coverage on Fluff Linux.
