# Translating Calculator

Calculator follows the language selected in KDE Plasma. Translation files are stored in the `translations` folder.

## Edit an existing language

Install Qt 6 translation tools. On Arch Linux and Fluff Linux they are included with Qt 6 Tools.

Open the desired `.ts` file with Qt Linguist. For example:

```sh
linguist translations/flufflinux-calculator_de.ts
```

Translate each source message, mark it finished, and save the file. Then rebuild and validate all catalogs:

```sh
make translations
make check-translations
```

## Add a language

Add one line to `translations/LANGUAGES`. Put the locale code first and the English language name second. Then run:

```sh
make update-translations
```

Open the new `.ts` file in Qt Linguist, complete it, and run the validation command.
The update command also adds the compiled catalog to the application resources.

Hebrew is available for manual review with native right to left layout mirroring. Mathematical expressions, digits, bits, and operators still require visual review. Arabic requires a separate translation and visual review before it is enabled.

## Test one language

Set the language for one launch:

```sh
LANGUAGE=de ./target/release/flufflinux-calculator
```

Also test the Plasma language setting because the application follows the ordered language list in `plasma-localerc`.

Check Basic, Advanced, Financial, Programming, Conversion, Preferences, About, History, every menu, and every tooltip. Long text must wrap or shrink without being cut off.

Test at the minimum width for every mode. Open Preferences and About. In Programming, test both the keypad and bits, open both operation menus, and open History. In Conversion, open both unit lists. Every sentence must remain visible. Scrollable areas must expose all of their content.
