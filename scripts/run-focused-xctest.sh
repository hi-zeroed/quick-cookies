#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 QuickCookiesTests/TestCase[/testMethod]" >&2
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$1"
DERIVED_DATA_PATH="${ROOT_DIR}/build/xctest-derived/${TARGET//\//-}-$(date +%Y%m%d-%H%M%S)-$$"

xcodebuild test \
  -project "${ROOT_DIR}/QuickCookies.xcodeproj" \
  -scheme QuickCookies \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -only-testing:"${TARGET}"
