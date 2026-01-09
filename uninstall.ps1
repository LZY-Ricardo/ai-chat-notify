[CmdletBinding()]
param(
  [AllowNull()][string]$InstallDir,
  [switch]$RemoveFromPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $InstallDir = Join-Path $env:LOCALAPPDATA 'ai-chat-notify\bin'
  } else {
    $InstallDir = Join-Path $env:USERPROFILE '.ai-chat-notify\bin'
  }
}

$files = @(
  'ai-chat-notify.ps1',
  'ai-chat-notify-inner.ps1',
  'ai-chat-notify.cmd',
  'configurator.ps1',
  'ai-chat-notify-config.cmd'
)

foreach ($file in $files) {
  $path = Join-Path $InstallDir $file
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force -ErrorAction Stop
  }
}

if (Test-Path -LiteralPath $InstallDir) {
  $remaining = Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue
  if (-not $remaining -or $remaining.Count -eq 0) {
    Remove-Item -LiteralPath $InstallDir -Force -ErrorAction Stop
  }
}

Write-Host "Uninstalled from: $InstallDir"

if ($RemoveFromPath) {
  $currentUserPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
  if ($null -eq $currentUserPath) { $currentUserPath = '' }

  $installDirNormalized = $InstallDir.Trim().TrimEnd('\')
  $newEntries = @()
  foreach ($entry in ($currentUserPath -split ';')) {
    $trimmed = if ($null -eq $entry) { '' } else { $entry.ToString() }
    $trimmed = $trimmed.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed.TrimEnd('\').ToLowerInvariant() -eq $installDirNormalized.ToLowerInvariant()) { continue }
    $newEntries += $trimmed
  }

  [Environment]::SetEnvironmentVariable('PATH', ($newEntries -join ';'), 'User')
  Write-Host "Removed from PATH (User). Restart your terminal to take effect."
}
