<#
.SYNOPSIS
    Builds the .fqa and creates a GitHub release with it as a downloadable asset.

.DESCRIPTION
    1. Runs scripts/build_fqa.py to (re)build the .fqa from src/*.lua
    2. Creates a GitHub release for the current version tag
    3. Uploads the .fqa as a release asset

.REQUIREMENTS
    - $env:GITHUB_PERSONAL_ACCESS_TOKEN must be set (needs repo + write:packages scope)
    - Python 3 must be available on PATH

.USAGE
    .\scripts\create_release.ps1
    .\scripts\create_release.ps1 -DryRun    # show what would happen, don't push
#>

param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
$Owner      = "arjancool"
$Repo       = "hc3-to-mqtt"
$TagName    = "v1.0.235-fork-1"
$ReleaseName = "v1.0.235-fork-1"
$FqaFile    = Join-Path $PSScriptRoot "..\hc3_to_mqtt_bridge-1.0.235-fork-1.fqa"
$ReleaseBody = @"
## Fibaro HC3 to MQTT Bridge — fork release

### Changes vs original v1.0.235
- **Heartbeat / Alive message** — publishes a periodic JSON status message to ``homeassistant/hc3-heartbeat``
  - Interval configurable via QuickApp variable ``hbInterval`` (default: 60 s)
  - Metadata (IP, version, counts) can be disabled via ``hbIncludeMeta=false``
- **Improved sensor device_class mapping** — unit-based mapping (A, V, W, kWh, °C, lx, Hz) instead of subtype-only
- **Auto-create optional variables** — no more "Variable not found" warnings on startup

### Installation
1. Download ``hc3_to_mqtt_bridge-1.0.235-fork-1.fqa``
2. Upload via HC3 web UI: **Settings → Devices → + → Other Device → Upload File**
3. Configure QuickApp variables: ``mqttUrl``, optionally ``mqttUsername`` / ``mqttPassword``, ``hbInterval``, ``hbIncludeMeta``
"@

# ---------------------------------------------------------------------------
# Step 1: build the .fqa
# ---------------------------------------------------------------------------
Write-Host "▶ Building .fqa..." -ForegroundColor Cyan
$buildScript = Join-Path $PSScriptRoot "build_fqa.py"
python $buildScript
if ($LASTEXITCODE -ne 0) { throw "build_fqa.py failed" }

$fqaResolved = Resolve-Path $FqaFile
Write-Host "  Built: $fqaResolved" -ForegroundColor Green

if ($DryRun) {
    Write-Host "`n[DryRun] Would create release '$TagName' and upload $($fqaResolved.Path)" -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# Step 2: create the GitHub release
# ---------------------------------------------------------------------------
$token = $env:GITHUB_PERSONAL_ACCESS_TOKEN
if (-not $token) { throw "GITHUB_PERSONAL_ACCESS_TOKEN is not set" }

$authHeader = @{ Authorization = "Bearer $token" }

Write-Host "`n▶ Creating GitHub release '$TagName'..." -ForegroundColor Cyan

$releasePayload = @{
    tag_name   = $TagName
    name       = $ReleaseName
    body       = $ReleaseBody
    draft      = $false
    prerelease = $false
}
$releaseJson = $releasePayload | ConvertTo-Json -Depth 5
$releaseBytes = [System.Text.Encoding]::UTF8.GetBytes($releaseJson)

$releaseResponse = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/$Owner/$Repo/releases" `
    -Method POST `
    -Headers ($authHeader + @{ "Content-Type" = "application/json" }) `
    -Body $releaseBytes

Write-Host "  Release URL: $($releaseResponse.html_url)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 3: upload the .fqa as a release asset
# ---------------------------------------------------------------------------
Write-Host "`n▶ Uploading .fqa asset..." -ForegroundColor Cyan

$uploadUrl = $releaseResponse.upload_url -replace '\{.*\}', ''
$fileName  = [System.IO.Path]::GetFileName($fqaResolved.Path)
$uploadUrl += "?name=$fileName"

$asset = Invoke-RestMethod `
    -Uri $uploadUrl `
    -Method POST `
    -Headers ($authHeader + @{ "Content-Type" = "application/octet-stream" }) `
    -InFile $fqaResolved.Path

Write-Host "  Download URL: $($asset.browser_download_url)" -ForegroundColor Green
Write-Host "`n✅ Done! Release published: $($releaseResponse.html_url)" -ForegroundColor Green
