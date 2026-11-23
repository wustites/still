# Generates the desktop runner folders that cannot be produced on another OS.
#
# Run this once on Windows:
#   powershell -ExecutionPolicy Bypass -File tool\bootstrap.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (Test-Path .flutter_scaffold) {
    Remove-Item -Recurse -Force .flutter_scaffold
}

flutter create `
    --platforms=windows,linux,macos `
    --project-name still `
    --org dev.still `
    .flutter_scaffold

foreach ($platform in @("windows", "linux", "macos")) {
    if (-not (Test-Path $platform)) {
        Copy-Item -Recurse -Force ".flutter_scaffold/$platform" .
    }
}
if (-not (Test-Path .metadata)) {
    Copy-Item -Force ".flutter_scaffold/.metadata" .
}
Remove-Item -Recurse -Force .flutter_scaffold

flutter pub get
dart run build_runner build --delete-conflicting-outputs

Write-Host ""
Write-Host "Done. Start the app with: flutter run -d windows"
