#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
language_file="$project_root/translations/LANGUAGES"
lupdate_tool=${LUPDATE:-/usr/lib/qt6/bin/lupdate}
lrelease_tool=${LRELEASE:-/usr/lib/qt6/bin/lrelease}

if [ ! -x "$lupdate_tool" ]; then
    lupdate_tool=$(command -v lupdate)
fi
if [ ! -x "$lrelease_tool" ]; then
    lrelease_tool=$(command -v lrelease)
fi

while read -r language language_name; do
    [ -n "$language" ] || continue
    catalog="$project_root/translations/flufflinux-calculator_${language}.ts"
    "$lupdate_tool" "$project_root/qml" \
        -extensions qml \
        -locations relative \
        -no-obsolete \
        -target-language "$language" \
        -ts "$catalog"
    "$lrelease_tool" "$catalog" \
        -qm "$project_root/translations/flufflinux-calculator_${language}.qm"
done < "$language_file"

resource_file="$project_root/resources.qrc"
resource_temp=$(mktemp)
trap 'rm -f "$resource_temp"' EXIT HUP INT TERM
{
    printf '%s\n' '<!DOCTYPE RCC>'
    printf '%s\n' '<RCC version="1.0">'
    printf '%s\n' '  <qresource prefix="/com/flufflinux/calculator">'
    printf '%s\n' '    <file alias="icon.svg">data/icons/hicolor/scalable/apps/com.flufflinux.calculator.svg</file>'
    while read -r language language_name; do
        [ -n "$language" ] || continue
        printf '    <file alias="translations/flufflinux-calculator_%s.qm">translations/flufflinux-calculator_%s.qm</file>\n' \
            "$language" "$language"
    done < "$language_file"
    printf '%s\n' '  </qresource>'
    printf '%s\n' '</RCC>'
} > "$resource_temp"
mv "$resource_temp" "$resource_file"
trap - EXIT HUP INT TERM
