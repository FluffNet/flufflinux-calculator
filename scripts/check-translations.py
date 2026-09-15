#!/usr/bin/env python3
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
language_file = root / "translations" / "LANGUAGES"
languages = [line.split()[0] for line in language_file.read_text().splitlines() if line.strip()]
errors = []
expected_languages = {
    "bg", "cs", "da", "de", "el", "es", "et", "fi", "fr", "ga",
    "he", "hr", "hu", "it", "ja", "lt", "lv", "mt", "nl", "pl", "pt",
    "ro", "ru", "sk", "sl", "sv",
}

if set(languages) != expected_languages:
    errors.append("LANGUAGES does not match the supported FLU language set")
if len(languages) != len(set(languages)):
    errors.append("LANGUAGES contains a duplicate locale")

desktop_file = root / "data" / "com.flufflinux.calculator.desktop"
desktop_text = desktop_file.read_text()
for key in ("Name",):
    localized_languages = set(re.findall(rf"^{key}\[([^]]+)\]=", desktop_text, re.MULTILINE))
    if localized_languages != expected_languages:
        errors.append(f"Desktop {key} translations do not match LANGUAGES")
for line in desktop_text.splitlines():
    if line.startswith("Keywords") and not line.endswith(";"):
        errors.append(f"Desktop keyword list must end with a semicolon: {line}")

catalog_languages = {
    path.stem.removeprefix("flufflinux-calculator_")
    for path in (root / "translations").glob("flufflinux-calculator_*.ts")
}
if catalog_languages != expected_languages:
    errors.append("Translation catalogs do not match LANGUAGES")

reference_sources = None

for language in languages:
    catalog = root / "translations" / f"flufflinux-calculator_{language}.ts"
    compiled = root / "translations" / f"flufflinux-calculator_{language}.qm"
    if not catalog.is_file():
        errors.append(f"Missing catalog for {language}")
        continue
    if not compiled.is_file() or compiled.stat().st_size == 0:
        errors.append(f"Missing compiled catalog for {language}")
    tree = ET.parse(catalog)
    if tree.getroot().get("language") != language:
        errors.append(f"{language}: catalog language attribute does not match")
    catalog_sources = {
        message.findtext("source") or ""
        for message in tree.findall(".//message")
    }
    if reference_sources is None:
        reference_sources = catalog_sources
    elif catalog_sources != reference_sources:
        errors.append(f"{language}: source messages differ from other catalogs")
    for message in tree.findall(".//message"):
        source = message.findtext("source") or ""
        translation = message.find("translation")
        translated = "" if translation is None else "".join(translation.itertext()).strip()
        if translation is None or translation.get("type") == "unfinished" or not translated:
            errors.append(f"{language}: unfinished: {source}")
            continue
        if "\u2013" in translated or "\u2014" in translated:
            errors.append(f"{language}: long dash found: {source}")
        if language == "he":
            if re.search(r"[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7]", translated):
                errors.append(f"he: niqqud found: {source}")
            if "בסדר" in translated:
                errors.append(f"he: disallowed confirmation label found: {source}")
            if "פלאף" in translated or "לינוקס" in translated:
                errors.append(f"he: Fluff Linux must remain in English: {source}")
        source_slots = sorted(re.findall(r"%\d+", source))
        translated_slots = sorted(re.findall(r"%\d+", translated))
        if source_slots != translated_slots:
            errors.append(f"{language}: placeholder mismatch: {source}")

if errors:
    print("\n".join(errors))
    sys.exit(1)

print(f"Checked {len(languages)} complete translation catalogs")
