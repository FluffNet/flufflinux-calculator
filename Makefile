APP_ID := com.flufflinux.calculator
PREFIX ?= /usr
DESTDIR ?=
FAKEROOT := $(CURDIR)/fakeroot
BINARY := target/release/flufflinux-calculator
DESKTOP_FILE := data/$(APP_ID).desktop
ICON_FILE := data/icons/hicolor/scalable/apps/$(APP_ID).svg
METAINFO_FILE := data/$(APP_ID).metainfo.xml
PKGINFO_FILE := .PKGINFO

.PHONY: all build fakeroot install translations update-translations check-translations

all: fakeroot

build:
	cargo build --release --locked

translations:
	@while read -r language language_name; do \
		/usr/lib/qt6/bin/lrelease \
			"translations/flufflinux-calculator_$${language}.ts" \
			-qm "translations/flufflinux-calculator_$${language}.qm"; \
	done < translations/LANGUAGES

update-translations:
	./scripts/update-translations.sh

check-translations: translations
	python3 scripts/check-translations.py

fakeroot: build
	$(MAKE) DESTDIR="$(FAKEROOT)" install
	install -Dm644 "$(PKGINFO_FILE)" "$(FAKEROOT)/.PKGINFO"

install:
	install -Dm755 "$(BINARY)" "$(DESTDIR)$(PREFIX)/bin/flufflinux-calculator"
	install -Dm644 "$(DESKTOP_FILE)" "$(DESTDIR)$(PREFIX)/share/applications/$(APP_ID).desktop"
	install -Dm644 "$(ICON_FILE)" "$(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/$(APP_ID).svg"
	install -Dm644 "$(METAINFO_FILE)" "$(DESTDIR)$(PREFIX)/share/metainfo/$(APP_ID).metainfo.xml"
	install -Dm644 LICENSE "$(DESTDIR)$(PREFIX)/share/licenses/flufflinux-calculator/LICENSE"
	install -Dm644 data/icons/NOTICE "$(DESTDIR)$(PREFIX)/share/licenses/flufflinux-calculator/ICON-NOTICE"
	@while read -r language language_name; do \
		install -Dm644 \
			"translations/flufflinux-calculator_$${language}.qm" \
			"$(DESTDIR)$(PREFIX)/share/flufflinux-calculator/translations/flufflinux-calculator_$${language}.qm"; \
	done < translations/LANGUAGES
