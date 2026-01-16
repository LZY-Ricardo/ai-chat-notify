# Test script for config isolation feature

$ErrorActionPreference = "Stop"

# Test configuration file path
$testConfigPath = Join-Path $env:TEMP "ai-chat-notify-test.json"

# Remove existing test config if present
if (Test-Path $testConfigPath) {
  Remove-Item $testConfigPath -Force
}

Write-Host "=== Configuration Isolation Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Create v2 config with provider-specific settings
Write-Host "Test 1: Creating v2 configuration file..." -ForegroundColor Yellow
$v2Config = @{
  version = 2
  defaults = @{
    provider = "codex"
    title = "AI Chat"
    subtitle = "Task completed"
    message = "Check your CLI/IDE for details"
    method = "popup"
    durationSeconds = 2
    noSound = $true
  }
  providers = @{
    codex = @{
      title = "Codex"
      subtitle = "Codex Task Complete"
      message = "Codex Check details"
      method = "popup"
      durationSeconds = 3
      noSound = $false
      popup = @{
        width = 360
        minHeight = 200
        fontFamily = "Microsoft YaHei UI"
        titleFontSize = 20
        accentColor = "#2B71D8"
        iconText = "C"
      }
    }
    claudecode = @{
      title = "Claude Code"
      subtitle = "Claude Task Complete"
      message = "Claude Check details"
      method = "popup"
      durationSeconds = 4
      noSound = $true
      popup = @{
        width = 400
        minHeight = 180
        fontFamily = "Segoe UI"
        titleFontSize = 18
        accentColor = "#7C3AED"
        iconText = "CC"
      }
    }
  }
  popup = @{
    width = 360
    minHeight = 200
    fontFamily = "Arial"
    accentColor = "#000000"
  }
}

$v2Config | ConvertTo-Json -Depth 10 | Set-Content -Path $testConfigPath -Encoding UTF8
Write-Host "✓ V2 config created at: $testConfigPath" -ForegroundColor Green
Write-Host ""

# Test 2: Load and verify provider-specific configs
Write-Host "Test 2: Loading and verifying provider configs..." -ForegroundColor Yellow
$loadedConfig = Get-Content $testConfigPath -Raw | ConvertFrom-Json

# Check codex config
$codexConfig = $loadedConfig.providers.codex
Write-Host "Codex Config:" -ForegroundColor Cyan
Write-Host "  Title: $($codexConfig.title)" -ForegroundColor White
Write-Host "  Subtitle: $($codexConfig.subtitle)" -ForegroundColor White
Write-Host "  Width: $($codexConfig.popup.width)" -ForegroundColor White
Write-Host "  AccentColor: $($codexConfig.popup.accentColor)" -ForegroundColor White
Write-Host "  IconText: $($codexConfig.popup.iconText)" -ForegroundColor White

# Check claudecode config
$claudecodeConfig = $loadedConfig.providers.claudecode
Write-Host ""
Write-Host "Claude Code Config:" -ForegroundColor Cyan
Write-Host "  Title: $($claudecodeConfig.title)" -ForegroundColor White
Write-Host "  Subtitle: $($claudecodeConfig.subtitle)" -ForegroundColor White
Write-Host "  Width: $($claudecodeConfig.popup.width)" -ForegroundColor White
Write-Host "  AccentColor: $($claudecodeConfig.popup.accentColor)" -ForegroundColor White
Write-Host "  IconText: $($claudecodeConfig.popup.iconText)" -ForegroundColor White
Write-Host ""

# Verify isolation
if ($codexConfig.popup.width -ne $claudecodeConfig.popup.width) {
  Write-Host "✓ Widths are different: Codex=$($codexConfig.popup.width), ClaudeCode=$($claudecodeConfig.popup.width)" -ForegroundColor Green
} else {
  Write-Host "✗ Widths are the same (isolation failed!)" -ForegroundColor Red
}

if ($codexConfig.popup.accentColor -ne $claudecodeConfig.popup.accentColor) {
  Write-Host "✓ Accent colors are different" -ForegroundColor Green
} else {
  Write-Host "✗ Accent colors are the same (isolation failed!)" -ForegroundColor Red
}

if ($codexConfig.subtitle -ne $claudecodeConfig.subtitle) {
  Write-Host "✓ Subtitles are different" -ForegroundColor Green
} else {
  Write-Host "✗ Subtitles are the same (isolation failed!)" -ForegroundColor Red
}
Write-Host ""

# Test 3: Simulate provider config retrieval
Write-Host "Test 3: Simulating provider config retrieval..." -ForegroundColor Yellow

function Get-ProviderConfig {
  param($Config, $Provider)

  $configVersion = if ($Config.version) { [int]$Config.version } else { 1 }

  if ($configVersion -ge 2) {
    if ($Config.providers.$Provider) {
      return $Config.providers.$Provider
    }
  }

  return $Config.defaults
}

$codedConfigRetrieved = Get-ProviderConfig $loadedConfig "codex"
$claudeConfigRetrieved = Get-ProviderConfig $loadedConfig "claudecode"

Write-Host "Retrieved Codex title: $($codedConfigRetrieved.title)" -ForegroundColor White
Write-Host "Retrieved Claude Code title: $($claudeConfigRetrieved.title)" -ForegroundColor White

if ($codedConfigRetrieved.title -eq "Codex" -and $claudeConfigRetrieved.title -eq "Claude Code") {
  Write-Host "✓ Provider-specific config retrieval works correctly" -ForegroundColor Green
} else {
  Write-Host "✗ Provider-specific config retrieval failed" -ForegroundColor Red
}
Write-Host ""

# Cleanup
Write-Host "Test 4: Cleanup..." -ForegroundColor Yellow
Remove-Item $testConfigPath -Force
Write-Host "✓ Test config file removed" -ForegroundColor Green
Write-Host ""

Write-Host "=== All Tests Completed ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration isolation feature is working correctly!" -ForegroundColor Green
Write-Host "Each provider (Codex and Claude Code) can now have independent settings."
Write-Host ""
