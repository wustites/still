#!/usr/bin/env bash
# Generates the desktop runner folders that cannot be produced on another OS.
#
# Run this once on the machine you develop on:
#   - Windows: tool/bootstrap.ps1
#   - Linux/macOS: tool/bootstrap.sh
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf .flutter_scaffold
flutter create \
  --platforms=windows,linux,macos \
  --project-name still \
  --org dev.still \
  .flutter_scaffold

for platform in windows linux macos; do
  if [ ! -d "$platform" ]; then
    cp -R ".flutter_scaffold/$platform" .
  fi
done
if [ ! -f .metadata ]; then
  cp .flutter_scaffold/.metadata .
fi
rm -rf .flutter_scaffold

flutter pub get
dart run build_runner build --delete-conflicting-outputs

echo
echo "Done. Start the app with: flutter run -d windows"
