$configPath = Join-Path $env:LOCALAPPDATA "ai-chat-notify\config.json"

Write-Host "Config file path: $configPath" -ForegroundColor Cyan

if (Test-Path $configPath) {
  Write-Host "Config file exists!" -ForegroundColor Green
  Write-Host ""

  $config = Get-Content $configPath -Raw | ConvertFrom-Json

  Write-Host "Config version: $($config.version)" -ForegroundColor Yellow
  Write-Host "Current provider in defaults: $($config.defaults.provider)" -ForegroundColor Yellow
  Write-Host ""

  if ($config.providers) {
    Write-Host "=== Providers Configuration ===" -ForegroundColor Cyan

    if ($config.providers.codex) {
      Write-Host ""
      Write-Host "Codex Config:" -ForegroundColor Green
      Write-Host "  Title: $($config.providers.codex.title)" -ForegroundColor White
      Write-Host "  Subtitle: $($config.providers.codex.subtitle)" -ForegroundColor White
      Write-Host "  Width: $($config.providers.codex.popup.width)" -ForegroundColor White
      Write-Host "  AccentColor: $($config.providers.codex.popup.accentColor)" -ForegroundColor White
    }

    if ($config.providers.claudecode) {
      Write-Host ""
      Write-Host "Claude Code Config:" -ForegroundColor Green
      Write-Host "  Title: $($config.providers.claudecode.title)" -ForegroundColor White
      Write-Host "  Subtitle: $($config.providers.claudecode.subtitle)" -ForegroundColor White
      Write-Host "  Width: $($config.providers.claudecode.popup.width)" -ForegroundColor White
      Write-Host "  AccentColor: $($config.providers.claudecode.popup.accentColor)" -ForegroundColor White
      Write-Host "  FontFamily: $($config.providers.claudecode.popup.fontFamily)" -ForegroundColor White
      Write-Host "  IconText: $($config.providers.claudecode.popup.iconText)" -ForegroundColor White
    }
  } else {
    Write-Host "No providers configuration found!" -ForegroundColor Red
  }
} else {
  Write-Host "Config file NOT found!" -ForegroundColor Red
  Write-Host "Please run configurator to create config file." -ForegroundColor Yellow
}
