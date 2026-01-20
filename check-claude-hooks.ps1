# Check Claude Code hooks configuration
$claudeSettingsPath = Join-Path $env:APPDATA "Claude\settings.json"

Write-Host "=== Checking Claude Code Hooks ===" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $claudeSettingsPath) {
  Write-Host "Found Claude settings at:" -ForegroundColor Green
  Write-Host "  $claudeSettingsPath" -ForegroundColor White
  Write-Host ""

  $settings = Get-Content $claudeSettingsPath -Raw | ConvertFrom-Json

  if ($settings.hooks) {
    Write-Host "Hooks configured:" -ForegroundColor Yellow

    foreach ($hookEvent in $settings.hooks.PSObject.Properties) {
      $eventName = $hookEvent.Name
      Write-Host ""
      Write-Host "  Event: $eventName" -ForegroundColor Cyan

      $hooks = $hookEvent.Value
      if ($hooks.PSObject.Properties) {
        foreach ($hookProp in $hooks.PSObject.Properties) {
          $matcher = $hookProp.Value.matcher
          $hookCommands = $hookProp.Value.hooks

          Write-Host "    Matcher: $matcher" -ForegroundColor White

          if ($hookCommands) {
            Write-Host "    Commands:" -ForegroundColor White
            foreach ($cmd in $hookCommands) {
              if ($cmd.command) {
                $commandStr = $cmd.command
                # Truncate if too long
                if ($commandStr.Length -gt 100) {
                  $commandStr = $commandStr.Substring(0, 100) + "..."
                }
                Write-Host "      - $commandStr" -ForegroundColor Gray
              }
            }
          }
        }
      }
    }
  } else {
    Write-Host "No hooks configured in Claude settings" -ForegroundColor Yellow
  }
} else {
  Write-Host "Claude settings NOT found at:" -ForegroundColor Red
  Write-Host "  $claudeSettingsPath" -ForegroundColor White
  Write-Host ""
  Write-Host "Checking alternative locations..." -ForegroundColor Yellow

  # Check for settings.local.json in current directory
  $localSettings = Join-Path $PWD ".claude\settings.local.json"
  if (Test-Path $localSettings) {
    Write-Host "Found .claude/settings.local.json in current directory" -ForegroundColor Green
    $settings = Get-Content $localSettings -Raw | ConvertFrom-Json

    if ($settings.hooks) {
      Write-Host "Hooks configured:" -ForegroundColor Yellow
      $settings.hooks.PSObject.Properties | ForEach-Object {
        Write-Host "  Event: $($_.Name)" -ForegroundColor Cyan
      }
    }
  } else {
    Write-Host "No settings found in .claue directory either" -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "=== Checking for Duplicate Hooks ===" -ForegroundColor Cyan
Write-Host ""

# Count hooks
if (Test-Path $claudeSettingsPath) {
  $settings = Get-Content $claudeSettingsPath -Raw | ConvertFrom-Json

  $totalHooks = 0
  $stopHooks = 0

  if ($settings.hooks.Stop) {
    $stopHooks = $settings.hooks.Stop.PSObject.Properties.Count
    foreach ($prop in $settings.hooks.Stop.PSObject.Properties) {
      $hookCount = $prop.Value.hooks.Count
      $totalHooks += $hookCount
      Write-Host "Stop event - Matcher: $($prop.Value.matcher), Hooks: $hookCount" -ForegroundColor White
    }
  }

  Write-Host ""
  Write-Host "Total Stop hooks: $totalHooks" -ForegroundColor Yellow

  if ($totalHooks -gt 1) {
    Write-Host ""
    Write-Host "WARNING: Multiple hooks detected! This is causing duplicate notifications." -ForegroundColor Red
    Write-Host "You should remove duplicate hooks and keep only one." -ForegroundColor Red
  }
}
