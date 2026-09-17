#!/bin/bash
set -euo pipefail

# QuickCookies 扩展打包脚本 (Alfred & Raycast)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALFRED_DIR="$PROJECT_ROOT/extensions/alfred"
RAYCAST_DIR="$PROJECT_ROOT/extensions/raycast"

echo "==> Packaging Alfred 5 Workflow..."
cd "$ALFRED_DIR"
rm -f QuickCookies.alfredworkflow
zip -r QuickCookies.alfredworkflow info.plist icon.png
echo "✓ Generated $ALFRED_DIR/QuickCookies.alfredworkflow"

echo "==> Validating Raycast Extension structure..."
cd "$RAYCAST_DIR"
test -f package.json
test -f icon.png
test -f src/preview-selected-file.ts
test -f src/preview-clipboard.ts
test -f src/create-code-card.ts
test -f src/preview-file.tsx
echo "✓ Raycast extension files verified."

echo "==> All extensions successfully packaged and verified!"
