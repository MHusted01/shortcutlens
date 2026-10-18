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

test:
	cd $(CORE) && swift test --enable-code-coverage
	python3 -I scripts/check-coverage.py "$$(cd $(CORE) && swift test --show-codecov-path)" $(COVERAGE_MIN)

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
	mkdir -p dist
	ditto -c -k --keepParent $(DERIVED)/Build/Products/Release/$(SCHEME).app dist/$(SCHEME)-$(VERSION).zip
	cd dist && shasum -a 256 $(SCHEME)-$(VERSION).zip > $(SCHEME)-$(VERSION).zip.sha256

clean:
	rm -rf $(DERIVED) dist $(PROJECT) $(CORE)/.build
