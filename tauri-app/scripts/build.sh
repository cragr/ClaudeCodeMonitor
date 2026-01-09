#!/bin/bash
# tauri-app/scripts/build.sh
set -e

cd "$(dirname "$0")/.."

echo "Building Tauri app..."
pnpm tauri build

echo "Build complete!"
ls -la src-tauri/target/release/bundle/
