#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: swiftlint is required. Install via: brew install swiftlint" >&2
  exit 1
fi

echo "==> SwiftLint (strict)"
swiftlint lint --strict --config "$ROOT_DIR/.swiftlint.yml"

XCODEPROJ_PATH="$(find "$ROOT_DIR" -maxdepth 2 -name "*.xcodeproj" | head -n 1 || true)"
if [[ -z "$XCODEPROJ_PATH" ]]; then
  echo "error: no .xcodeproj found. Add the Xcode project, then rerun strict checks." >&2
  exit 1
fi

PROJECT_NAME="$(basename "$XCODEPROJ_PATH" .xcodeproj)"
SCHEME="${SCHEME:-$PROJECT_NAME}"
DESTINATION="${DESTINATION:-platform=macOS}"

echo "==> xcodebuild strict compile checks"
xcodebuild \
  -project "$XCODEPROJ_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_COMPILATION_MODE=wholemodule \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG STRICT_LINT" \
  OTHER_SWIFT_FLAGS="-warnings-as-errors -Xfrontend -warn-long-function-bodies=80 -Xfrontend -warn-long-expression-type-checking=120" \
  OTHER_CFLAGS="-Weverything -Werror -Wno-c++98-compat -Wno-c++98-compat-pedantic -Wno-padded -Wno-documentation-unknown-command -Wno-gnu-zero-variadic-macro-arguments -Wno-disabled-macro-expansion -Wno-declaration-after-statement" \
  CLANG_WARN_DOCUMENTATION_COMMENTS=YES \
  CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF=YES \
  CLANG_WARN_OBJC_LITERAL_CONVERSION=YES \
  CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER=YES \
  CLANG_WARN_STRICT_PROTOTYPES=YES \
  CLANG_WARN_COMMA=YES \
  CLANG_WARN_UNGUARDED_AVAILABILITY=YES \
  CLANG_WARN_SUSPICIOUS_MOVE=YES \
  CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED=YES \
  clean build

echo "==> strict checks passed"
