APP_NAME := NullMoth Monitor
BUNDLE   := build/$(APP_NAME).app
CONFIG   ?= release
PREFIX   ?= /usr/local

.PHONY: build test app run install uninstall clean

build:
	swift build -c $(CONFIG)

test:
	swift test

app: build
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp ".build/$(CONFIG)/NullMothMonitor" "$(BUNDLE)/Contents/MacOS/NullMothMonitor"
	cp Support/Info.plist "$(BUNDLE)/Contents/Info.plist"
	printf 'APPL????' > "$(BUNDLE)/Contents/PkgInfo"
	codesign --force --sign - "$(BUNDLE)" >/dev/null 2>&1 || true
	@echo "Built $(BUNDLE)"

run: app
	open "$(BUNDLE)"

install: build
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 0755 ".build/$(CONFIG)/nullmoth-mon" "$(DESTDIR)$(PREFIX)/bin/nullmoth-mon"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/nullmoth-mon"

clean:
	swift package clean
	rm -rf build
