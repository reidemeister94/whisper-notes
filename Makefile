.PHONY: clean setup-dev-env install-tools build build-release test lint lint-fix format app-bundle \
       fetch-tags changelog bump bump-version-minor bump-version-major bump-version-patch push-tag help

VERSION := $(shell cat VERSION 2>/dev/null || echo "0.0.0")

# ─── Housekeeping ────────────────────────────────────────────────────

clean:
	rm -rf .build
	rm -rf WhisperNotes.app
	rm -rf *.profdata *.profraw
	find . -name .DS_Store -delete

help:
	@echo "WhisperNotes Development Targets"
	@echo "─────────────────────────────────"
	@echo "  setup-dev-env  Install tools + pre-commit hooks"
	@echo "  clean          Remove build artifacts"
	@echo "  build          Debug build"
	@echo "  build-release  Release build"
	@echo "  test           Run all tests"
	@echo "  lint           Run SwiftLint"
	@echo "  lint-fix       Run SwiftLint with auto-fix"
	@echo "  format         Run SwiftFormat (auto-fix)"
	@echo "  app-bundle     Build signed .app bundle"
	@echo "  bump           Bump version (auto-detect)"
	@echo "  changelog      Generate changelog"

# ─── Dev Environment ─────────────────────────────────────────────────

install-tools:
	@command -v brew >/dev/null 2>&1 || { echo "Error: Homebrew not installed. Install from https://brew.sh"; exit 1; }
	@command -v swiftlint >/dev/null 2>&1 || { echo "Installing SwiftLint..."; brew install swiftlint; }
	@command -v swiftformat >/dev/null 2>&1 || { echo "Installing SwiftFormat..."; brew install swiftformat; }
	@command -v pre-commit >/dev/null 2>&1 || { echo "Installing pre-commit..."; brew install pre-commit; }
	@command -v cz >/dev/null 2>&1 || { echo "Installing commitizen..."; brew install commitizen; }
	@echo "All tools installed."

setup-dev-env: install-tools
	pre-commit install
	pre-commit install --hook-type commit-msg
	@echo "Dev environment ready. Pre-commit hooks installed."

# ─── Build ───────────────────────────────────────────────────────────

build:
	swift build

build-release:
	swift build -c release

# ─── Test ────────────────────────────────────────────────────────────

test:
	swift test

# ─── Lint & Format ───────────────────────────────────────────────────

lint:
	swiftlint lint --strict Sources/ Tests/

lint-fix:
	swiftlint lint --fix Sources/ Tests/

format:
	swiftformat Sources/ Tests/

# ─── App Bundle ──────────────────────────────────────────────────────

app-bundle:
	./build.sh

# ─── Versioning (commitizen) ─────────────────────────────────────────

fetch-tags:
	git fetch --tags

changelog:
	cz changelog --unreleased-version v$(VERSION)

bump: fetch-tags
	cz bump

bump-version-minor: fetch-tags
	cz bump --increment MINOR

bump-version-major: fetch-tags
	cz bump --increment MAJOR

bump-version-patch: fetch-tags
	cz bump --increment PATCH

push-tag: fetch-tags
	git push --follow-tags origin main
