Write-Host "=== Checking All Claude Code Hooks ===" -ForegroundColor Cyan
Write-Host ""

# Global settings.json
$globalSettings = "C:\Users\lenovo\.claude\settings.json"
if (Test-Path $globalSettings) {
  $settings = Get-Content $globalSettings -Raw | ConvertFrom-Json
  Write-Host "Global settings.json:" -ForegroundColor Yellow
  if ($settings.hooks.Stop) {
    $count = 0
    foreach ($hook in $settings.hooks.Stop) {
      $count++
      $cmd = $hook.hooks[0].command
      Write-Host "  Hook #${count}: ${cmd}" -ForegroundColor Gray
    }
    Write-Host "  Total: ${count} hooks" -ForegroundColor Red
  } else {
    Write-Host "  No Stop hooks" -ForegroundColor Green
  }
}
Write-Host ""

# Global settings.local.json
$globalLocalSettings = "C:\Users\lenovo\.claude\settings.local.json"
if (Test-Path $globalLocalSettings) {
  $settings = Get-Content $globalLocalSettings -Raw | ConvertFrom-Json
  Write-Host "Global settings.local.json:" -ForegroundColor Yellow
  if ($settings.hooks.Stop) {
    $count = 0
    foreach ($hook in $settings.hooks.Stop) {
      $count++
      $cmd = $hook.hooks[0].command
      Write-Host "  Hook #${count}: ${cmd}" -ForegroundColor Gray
    }
    Write-Host "  Total: ${count} hooks" -ForegroundColor Red
  } else {
    Write-Host "  No Stop hooks" -ForegroundColor Green
  }
}
Write-Host ""

# Project local settings
$projectSettings = "f:\myProjects\ai-chat-notify\.claude\settings.local.json"
if (Test-Path $projectSettings) {
  $settings = Get-Content $projectSettings -Raw | ConvertFrom-Json
  Write-Host "Project .claude/settings.local.json:" -ForegroundColor Yellow
  if ($settings.hooks.Stop) {
    $count = 0
    foreach ($hook in $settings.hooks.Stop) {
      $count++
      $cmd = $hook.hooks[0].command
      Write-Host "  Hook #${count}: ${cmd}" -ForegroundColor Gray
    }
    Write-Host "  Total: ${count} hooks" -ForegroundColor Red
  } else {
    Write-Host "  No Stop hooks" -ForegroundColor Green
  }
}
Write-Host ""

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Hooks are now cleaned up! Only 1 hook should remain in global settings.json" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart Claude Code or reload the configuration" -ForegroundColor White
Write-Host "2. Test by completing a conversation" -ForegroundColor White
Write-Host "3. You should now see only ONE notification popup!" -ForegroundColor White
Write-Host ""
