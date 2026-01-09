[CmdletBinding()]
param(
  [AllowNull()][string]$InstallDir,
  [switch]$AddToPath,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $InstallDir = Join-Path $env:LOCALAPPDATA 'ai-chat-notify\bin'
  } else {
    $InstallDir = Join-Path $env:USERPROFILE '.ai-chat-notify\bin'
  }
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$items = @(
  @{ Source = 'scripts\ai-chat-notify.ps1'; Destination = 'ai-chat-notify.ps1' },
  @{ Source = 'scripts\ai-chat-notify-inner.ps1'; Destination = 'ai-chat-notify-inner.ps1' },
  @{ Source = 'scripts\ai-chat-notify.cmd'; Destination = 'ai-chat-notify.cmd' },
  @{ Source = 'configurator.ps1'; Destination = 'configurator.ps1' },
  @{ Source = 'ai-chat-notify-config.cmd'; Destination = 'ai-chat-notify-config.cmd' }
)

foreach ($item in $items) {
  $src = Join-Path $repoRoot $item.Source
  $dst = Join-Path $InstallDir $item.Destination

  if (-not (Test-Path -LiteralPath $src)) {
    throw "Missing source file: $src"
  }

  if ((Test-Path -LiteralPath $dst) -and -not $Force) {
    throw "Destination exists: $dst (re-run with -Force to overwrite)"
  }

  Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
}

Write-Host "Installed: $InstallDir"

if ($AddToPath) {
  $currentUserPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
  if ($null -eq $currentUserPath) { $currentUserPath = '' }

  $installDirNormalized = (Resolve-Path -LiteralPath $InstallDir).Path.TrimEnd('\')
  $alreadyInPath = $false

  foreach ($entry in ($currentUserPath -split ';')) {
    $trimmed = if ($null -eq $entry) { '' } else { $entry.ToString() }
    $trimmed = $trimmed.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed.TrimEnd('\').ToLowerInvariant() -eq $installDirNormalized.ToLowerInvariant()) {
      $alreadyInPath = $true
      break
    }
  }

  if (-not $alreadyInPath) {
    $newUserPath = if ([string]::IsNullOrWhiteSpace($currentUserPath)) {
      $installDirNormalized
    } else {
      $currentUserPath.TrimEnd(';') + ';' + $installDirNormalized
    }
    [Environment]::SetEnvironmentVariable('PATH', $newUserPath, 'User')
    Write-Host "Added to PATH (User). Restart your terminal to take effect."
  } else {
    Write-Host "PATH already contains install directory."
  }
}

Write-Host 'Test:'
Write-Host '  ai-chat-notify -Title "Test" -Subtitle "Turn complete" -Message "Hello" -Method popup -DurationSeconds 2 -NoSound'
Write-Host 'Config:'
Write-Host '  ai-chat-notify-config'
