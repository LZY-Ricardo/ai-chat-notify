$configPath = Join-Path $env:LOCALAPPDATA "ai-chat-notify\config.json"

Write-Host "Reading config from: $configPath" -ForegroundColor Cyan

$config = Get-Content $configPath -Raw | ConvertFrom-Json

Write-Host "Current config version: $($config.version)" -ForegroundColor Yellow

# Check if providers object exists
if (-not $config.providers) {
  Write-Host "Creating providers object..." -ForegroundColor Yellow
  $config | Add-Member -NotePropertyName providers -NotePropertyValue (@{})
}

# Check if codex config exists
if (-not $config.providers.codex) {
  Write-Host "Adding codex provider configuration..." -ForegroundColor Yellow

  $codexConfig = @{
    title = "Codex"
    subtitle = "Task completed"
    message = "Check your CLI/IDE for details"
    method = "popup"
    durationSeconds = 2
    noSound = $true
    popup = @{
      width = 360
      minHeight = 200
      fontFamily = "Microsoft YaHei UI"
      titleFontSize = 20
      subtitleFontSize = 18
      messageFontSize = 14
      titleColor = "#111827"
      subtitleColor = "#111827"
      messageColor = "#374151"
      backgroundColor = "#FFFFFF"
      borderColor = "#E6E8EB"
      dividerColor = "#EEF0F2"
      accentColor = "#2B71D8"
      iconText = "C"
      iconTextColor = "#FFFFFF"
      iconBackgroundColor = "#2B71D8"
      okText = "OK"
    }
  }

  $config.providers | Add-Member -NotePropertyName codex -NotePropertyValue $codexConfig -Force
  Write-Host "✓ Codex config added" -ForegroundColor Green
} else {
  Write-Host "Codex config already exists" -ForegroundColor Green
}

# Check if claudecode config exists
if (-not $config.providers.claudecode) {
  Write-Host "Adding claudecode provider configuration..." -ForegroundColor Yellow

  $claudecodeConfig = @{
    title = "Claude Code"
    subtitle = "Task Complete"
    message = "Check your CLI/IDE for details."
    method = "popup"
    durationSeconds = 2
    noSound = $true
    popup = @{
      width = 400
      minHeight = 180
      fontFamily = "Segoe UI"
      titleFontSize = 18
      subtitleFontSize = 16
      messageFontSize = 13
      titleColor = "#1F2937"
      subtitleColor = "#4B5563"
      messageColor = "#6B7280"
      backgroundColor = "#FAFAFA"
      borderColor = "#D1D5DB"
      dividerColor = "#E5E7EB"
      accentColor = "#7C3AED"
      iconText = "CC"
      iconTextColor = "#FFFFFF"
      iconBackgroundColor = "#7C3AED"
      okText = "OK"
    }
  }

  $config.providers | Add-Member -NotePropertyName claudecode -NotePropertyValue $claudecodeConfig -Force
  Write-Host "✓ Claude Code config added" -ForegroundColor Green
} else {
  Write-Host "Claude Code config already exists" -ForegroundColor Green
}

# Save the updated config
Write-Host "Saving updated config..." -ForegroundColor Yellow
$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8

Write-Host ""
Write-Host "✓ Config file updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Both provider configurations now exist in the config file." -ForegroundColor Cyan
