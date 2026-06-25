#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

failures=0
warnings=0

pass() {
  printf "PASS %s\n" "$1"
}

warn() {
  printf "WARN %s\n" "$1"
  warnings=$((warnings + 1))
}

fail() {
  printf "FAIL %s\n" "$1"
  failures=$((failures + 1))
}

require_file() {
  if [ -f "$1" ]; then
    pass "$1 exists"
  else
    fail "$1 missing"
  fi
}

require_dir() {
  if [ -d "$1" ]; then
    pass "$1 exists"
  else
    fail "$1 missing"
  fi
}

require_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"

  if [ ! -f "$file" ]; then
    fail "$file missing for $label"
    return
  fi

  if grep -q "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

printf "some local readiness check\n"
printf "Repo: %s\n\n" "$ROOT"

require_dir "some.xcodeproj"
require_file "some.xcodeproj/project.pbxproj"
require_file "some.xcodeproj/xcshareddata/xcschemes/some.xcscheme"
require_file "some/SomeApp.swift"
require_file "some/Info.plist"
require_file "some/some.entitlements"
require_file "SomeShareExtension/ShareViewController.swift"
require_file "SomeShareExtension/SomeShareExtension.entitlements"
require_file "SomeWidget/SomeWidget.swift"
require_file "SomeWidget/SomeWidget.entitlements"
require_file "SomeTests/SomeTests.swift"
require_file ".github/workflows/ios-ci.yml"
require_file ".github/workflows/ios-testflight.yml"
require_file "README.md"
require_file "docs/local-install-and-first-use.md"
require_file "docs/online-build-and-release.md"

require_grep "APP_GROUP_IDENTIFIER" "some.xcodeproj/project.pbxproj" "project exposes App Group build setting"
require_grep "com.apple.security.application-groups" "some/some.entitlements" "main app has App Group entitlement"
require_grep "com.apple.security.application-groups" "SomeShareExtension/SomeShareExtension.entitlements" "share extension has App Group entitlement"
require_grep "com.apple.security.application-groups" "SomeWidget/SomeWidget.entitlements" "widget has App Group entitlement"
require_grep "actions/checkout@v5" ".github/workflows/ios-ci.yml" "CI workflow uses current checkout action"
require_grep "macos-15" ".github/workflows/ios-ci.yml" "CI workflow uses modern macOS runner"

if command -v git >/dev/null 2>&1; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass "git repository detected"
    status="$(git status --short)"
    if [ -z "$status" ]; then
      pass "working tree is clean"
    else
      warn "working tree has uncommitted changes"
      printf "%s\n" "$status"
    fi
  else
    warn "directory is not a git worktree"
  fi
else
  warn "git is not installed"
fi

if command -v xcodebuild >/dev/null 2>&1; then
  if version_raw="$(xcodebuild -version 2>&1)"; then
    version_output="$(printf "%s" "$version_raw" | tr '\n' ' ')"
    pass "xcodebuild available: $version_output"
    major_version="$(printf "%s\n" "$version_raw" | awk '/Xcode/ { split($2, parts, "."); print parts[1]; exit }')"
    case "$major_version" in
      ''|*[!0-9]*)
        warn "could not parse Xcode major version"
        ;;
      *)
        if [ "$major_version" -lt 16 ]; then
          warn "Xcode 16 or newer is recommended for this project"
        else
          pass "Xcode major version is 16 or newer"
        fi
        ;;
    esac

    xcode_list_log="$(mktemp)"
    if xcodebuild -list -project some.xcodeproj >"$xcode_list_log" 2>&1; then
      pass "xcodebuild can read some.xcodeproj"
      if grep -q "some" "$xcode_list_log"; then
        pass "scheme list includes some"
      else
        warn "xcodebuild list did not show scheme some"
      fi
    else
      warn "xcodebuild could not list project; open it in Xcode to inspect signing and SDK setup"
      tail -20 "$xcode_list_log" || true
    fi
    rm -f "$xcode_list_log"
  else
    warn "xcodebuild command exists but selected developer directory is not usable"
    printf "%s\n" "$version_raw"
  fi
else
  warn "xcodebuild is not installed"
fi

if command -v xcrun >/dev/null 2>&1; then
  if xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
    pass "iPhone Simulator SDK is available"
  else
    warn "iPhone Simulator SDK is not available in the selected Xcode"
  fi
else
  warn "xcrun is not installed"
fi

printf "\nSummary: %d failure(s), %d warning(s)\n" "$failures" "$warnings"

if [ "$failures" -gt 0 ]; then
  printf "Project readiness failed. Fix missing project files first.\n"
  exit 1
fi

printf "Project structure is ready. Warnings usually mean local Xcode/signing setup still needs attention.\n"
exit 0
