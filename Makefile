APP_NAME      := NullMoth Monitor
BUNDLE        := build/$(APP_NAME).app
CONFIG        ?= release
PREFIX        ?= /usr/local
UNIVERSAL_DIR := .build/universal
ARM64_TRIPLE  := arm64-apple-macosx14.0
X86_64_TRIPLE := x86_64-apple-macosx14.0

.PHONY: build test icon app universal app-universal run install install-universal uninstall clean

build:
	swift build -c $(CONFIG)

test:
	swift test

icon:
	swift Scripts/GenerateIcon.swift
	./Scripts/make-icon.sh

app: build
	./Scripts/bundle.sh ".build/$(CONFIG)/NullMothMonitor"

universal:
	swift build -c $(CONFIG) --triple $(ARM64_TRIPLE) --scratch-path .build/arm64
	swift build -c $(CONFIG) --triple $(X86_64_TRIPLE) --scratch-path .build/x86_64
	mkdir -p "$(UNIVERSAL_DIR)"
	arm64_bin="$$(swift build -c $(CONFIG) --triple $(ARM64_TRIPLE) --scratch-path .build/arm64 --show-bin-path)"; \
	x86_64_bin="$$(swift build -c $(CONFIG) --triple $(X86_64_TRIPLE) --scratch-path .build/x86_64 --show-bin-path)"; \
	lipo -create "$$arm64_bin/NullMothMonitor" "$$x86_64_bin/NullMothMonitor" -output "$(UNIVERSAL_DIR)/NullMothMonitor"; \
	lipo -create "$$arm64_bin/nullmoth-mon" "$$x86_64_bin/nullmoth-mon" -output "$(UNIVERSAL_DIR)/nullmoth-mon"; \
	lipo -info "$(UNIVERSAL_DIR)/NullMothMonitor"; \
	lipo -info "$(UNIVERSAL_DIR)/nullmoth-mon"

app-universal: universal
	./Scripts/bundle.sh "$(UNIVERSAL_DIR)/NullMothMonitor"

run: app
	open "$(BUNDLE)"

install: build
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 0755 ".build/$(CONFIG)/nullmoth-mon" "$(DESTDIR)$(PREFIX)/bin/nullmoth-mon"

install-universal: universal
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 0755 "$(UNIVERSAL_DIR)/nullmoth-mon" "$(DESTDIR)$(PREFIX)/bin/nullmoth-mon"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/nullmoth-mon"

clean:
	swift package clean
	rm -rf build .build/arm64 .build/x86_64 .build/universal
