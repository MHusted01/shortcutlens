PROJECT := ShortcutLens.xcodeproj
SCHEME := ShortcutLens
DERIVED := build
CORE := ShortcutLensCore
COVERAGE_MIN := 80
BUILD_NUMBER ?= 1

.PHONY: generate build test integration lint check release clean

generate:
	xcodegen generate --quiet

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) build

# xcodebuild, not `swift test`: SwiftPM before Xcode 27 copies Core's
# .xcstrings instead of compiling it. Tests run in English on any machine.
test:
	rm -rf $(DERIVED)/CoreTests.xcresult
	cd $(CORE) && xcodebuild test -scheme $(CORE) -destination 'platform=macOS' \
		-derivedDataPath ../$(DERIVED)/core -enableCodeCoverage YES -testLanguage en -testRegion US \
		-resultBundlePath ../$(DERIVED)/CoreTests.xcresult -quiet
	xcrun xccov view --report --json $(DERIVED)/CoreTests.xcresult > $(DERIVED)/coverage.json
	python3 -I scripts/check-coverage.py $(DERIVED)/coverage.json $(COVERAGE_MIN)

# Local only: needs the Accessibility permission for ShortcutLens.app.
integration: generate
	xcodebuild -project $(PROJECT) -scheme ShortcutLensIntegration -configuration Debug \
		-derivedDataPath $(DERIVED) test

lint:
	swiftlint lint --strict
	swiftformat --lint .

check:
	bash scripts/check-no-telemetry.sh

release: generate
	@test -n "$(VERSION)" || (echo "error: set VERSION, e.g. make release VERSION=0.1.0" && exit 1)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(DERIVED) MARKETING_VERSION=$(VERSION) \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) build
	codesign --verify --deep --strict $(DERIVED)/Build/Products/Release/$(SCHEME).app
	# Stripped binary: only __mh_execute_header stays defined (#162).
	for arch in arm64 x86_64; do \
		nm -U -arch $$arch $(DERIVED)/Build/Products/Release/$(SCHEME).app/Contents/MacOS/$(SCHEME) > $(DERIVED)/syms.txt && \
		test "$$(wc -l < $(DERIVED)/syms.txt)" -eq 1 || exit 1; \
	done
	mkdir -p dist
	ditto -c -k --keepParent $(DERIVED)/Build/Products/Release/$(SCHEME).app dist/$(SCHEME)-$(VERSION).zip
	# Symbols for crash reports; release.yml publishes every dist/*.zip.
	ditto -c -k --keepParent $(DERIVED)/Build/Products/Release/$(SCHEME).app.dSYM dist/$(SCHEME)-$(VERSION).dSYM.zip
	cd dist && shasum -a 256 $(SCHEME)-$(VERSION).zip > $(SCHEME)-$(VERSION).zip.sha256

clean:
	rm -rf $(DERIVED) dist $(PROJECT) $(CORE)/.build
