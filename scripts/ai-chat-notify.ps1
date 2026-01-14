[CmdletBinding()]
param(
  [AllowNull()][string]$Title,
  [AllowNull()][string]$Subtitle,
  [AllowNull()][string]$Message,
  [ValidateSet("balloon", "popup")]
  [string]$Method,
  [ValidateRange(0, 120)]
  [int]$DurationSeconds,
  [switch]$NoSound,
  [AllowNull()][string]$EventJson,
  [AllowNull()][string]$EventFile,
  [AllowNull()][string]$Provider = "auto",
  [AllowNull()][string]$LogPath,
  [AllowNull()][string]$ConfigPath
)

function Get-NotifyEnvValue {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string[]]$FallbackNames = @()
  )

  foreach ($n in @($Name) + $FallbackNames) {
    if ([string]::IsNullOrWhiteSpace($n)) { continue }
    $v = [Environment]::GetEnvironmentVariable($n)
    if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
  }
  return $null
}

function Get-DefaultConfigPath {
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
      return (Join-Path (Join-Path $env:LOCALAPPDATA "ai-chat-notify") "config.json")
    }
  } catch {}

  try {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
      return (Join-Path (Join-Path $env:USERPROFILE ".ai-chat-notify") "config.json")
    }
  } catch {}

  return $null
}

function Load-NotifyConfig {
  param([AllowNull()][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    return ($raw | ConvertFrom-Json -ErrorAction Stop)
  } catch {
    Write-NotifyLog ("config read error: {0}" -f $_.Exception.Message)
    return $null
  }
}

function Write-NotifyLog {
  param([Parameter(Mandatory = $true)][string]$Text)
  $logPath = $script:NotifyLogPath
  if ([string]::IsNullOrWhiteSpace($logPath)) { return }
  try {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    Add-Content -Path $logPath -Encoding UTF8 -Value "[$ts] ai-chat-notify $Text"
  } catch {}
}

function Truncate-Text {
  param(
    [AllowNull()][string]$Text,
    [Parameter(Mandatory = $true)][int]$MaxLength
  )
  if ($null -eq $Text) { return $null }
  if ($Text.Length -le $MaxLength) { return $Text }
  if ($MaxLength -le 1) { return $Text.Substring(0, $MaxLength) }
  return ($Text.Substring(0, [Math]::Max(0, $MaxLength - 3)) + "...")
}

function Get-FirstLine {
  param([AllowNull()][string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  return (($Text -split "(\r\n|\r|\n)")[0]).Trim()
}

function Test-ToastNotificationsEnabled {
  try {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Software\\Microsoft\\Windows\\CurrentVersion\\PushNotifications")
    if ($null -eq $key) { return $true }
    $value = $key.GetValue("ToastEnabled", $null)
    if ($null -eq $value) { return $true }
    return ([int]$value -ne 0)
  } catch {
    return $true
  }
}

function TryParse-JsonLikeString {
  param([AllowNull()][string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

  $t = $Text.Trim()
  if (-not ($t.StartsWith("{") -or $t.StartsWith("[") -or ($t.StartsWith('"') -and $t.Contains("{")))) {
    return $null
  }

  $candidates = New-Object System.Collections.Generic.List[string]
  $candidates.Add($t)
  if ($t.Length -ge 2 -and $t[0] -eq '"' -and $t[$t.Length - 1] -eq '"') {
    $candidates.Add($t.Substring(1, $t.Length - 2))
  }

  foreach ($c in @($candidates.ToArray())) {
    $candidates.Add(($c -replace '\\\"', '"'))
  }

  $seen = @{}
  foreach ($c in $candidates) {
    if ([string]::IsNullOrWhiteSpace($c)) { continue }
    if ($seen.ContainsKey($c)) { continue }
    $seen[$c] = $true
    try {
      return ($c | ConvertFrom-Json -ErrorAction Stop)
    } catch {}
  }

  return $null
}

function Test-Truthy {
  param([AllowNull()][object]$Value)
  if ($null -eq $Value) { return $false }
  if ($Value -is [bool]) { return $Value }
  $s = $Value.ToString().Trim().ToLowerInvariant()
  return @("1", "true", "yes", "y", "on").Contains($s)
}

function Get-ObjectProperty {
  param(
    [Parameter(Mandatory = $true)][object]$Object,
    [Parameter(Mandatory = $true)][string[]]$Names
  )
  foreach ($name in $Names) {
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    try {
      $p = $Object.PSObject.Properties[$name]
      if ($null -ne $p) { return $p.Value }
    } catch {}
  }
  return $null
}

function Resolve-Provider {
  param(
    [Parameter(Mandatory = $false)][string]$ProviderParam,
    [Parameter(Mandatory = $true)][AllowNull()][object]$Event
  )

  if (-not [string]::IsNullOrWhiteSpace($ProviderParam)) {
    $raw = $ProviderParam.Trim()
    $normalized = $raw.ToLowerInvariant() -replace "[ _]", "-"
      if ($normalized -ne "auto") {
        if ($normalized -eq "claude" -or $normalized -eq "claude-code" -or $normalized -eq "claudecode") { return "claudecode" }
        if ($normalized -eq "codex") { return "codex" }
        if ($normalized -eq "generic") { return "generic" }
        return $normalized
      }
  }
  if ($null -eq $Event) { return "generic" }

  $p = Get-ObjectProperty $Event @("provider", "source", "app")
  if (-not [string]::IsNullOrWhiteSpace($p)) {
    $raw = $p.ToString().Trim()
    $normalized = $raw.ToLowerInvariant() -replace "[ _]", "-"
    if ($normalized -eq "claude" -or $normalized -eq "claude-code" -or $normalized -eq "claudecode") { return "claudecode" }
    if ($normalized -eq "codex") { return "codex" }
    return $normalized
  }

  $t = Get-ObjectProperty $Event @("type", "eventType", "event_type")
  if (-not [string]::IsNullOrWhiteSpace($t)) {
    $typeText = $t.ToString()
    if ($typeText -eq "agent-turn-complete" -or $typeText -like "agent-*") { return "codex" }
  }

  return "generic"
}

$script:NotifyLogPath = $null
try {
  if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $script:NotifyLogPath = $LogPath
  } else {
    $script:NotifyLogPath = Get-NotifyEnvValue "AI_CHAT_NOTIFY_LOG" @("CODEX_NOTIFY_LOG")
  }
} catch {}

$defaultTitle = "AI Chat"
$defaultSubtitle = "Turn complete"
$defaultMessage = "Check your CLI/IDE for details."

$configPathValue = $ConfigPath
if ([string]::IsNullOrWhiteSpace($configPathValue)) {
  $configPathValue = Get-NotifyEnvValue "AI_CHAT_NOTIFY_CONFIG_PATH" @("CODEX_NOTIFY_CONFIG_PATH")
}
if ([string]::IsNullOrWhiteSpace($configPathValue)) {
  $configPathValue = Get-DefaultConfigPath
}

$notifyConfig = Load-NotifyConfig $configPathValue
$configDefaults = if ($null -eq $notifyConfig) { $null } else { (Get-ObjectProperty $notifyConfig @("defaults")) }
$configTitle = if ($null -eq $configDefaults) { $null } else { (Get-ObjectProperty $configDefaults @("title")) }
$configSubtitle = if ($null -eq $configDefaults) { $null } else { (Get-ObjectProperty $configDefaults @("subtitle")) }
$configMessage = if ($null -eq $configDefaults) { $null } else { (Get-ObjectProperty $configDefaults @("message")) }
$configMethod = if ($null -eq $configDefaults) { $null } else { (Get-ObjectProperty $configDefaults @("method")) }
$configDurationSeconds = if ($null -eq $configDefaults) { $null } else { (Get-ObjectProperty $configDefaults @("durationSeconds", "duration_seconds")) }
$configNoSound = if ($null -eq $configDefaults) { $null } else { (Get-ObjectProperty $configDefaults @("noSound", "nosound", "no_sound", "silent")) }
$configProvider = if ($null -eq $configDefaults) { $null } else { (Get-ObjectProperty $configDefaults @("provider")) }

if (-not [string]::IsNullOrWhiteSpace($configTitle)) { $defaultTitle = $configTitle.ToString() }
if (-not [string]::IsNullOrWhiteSpace($configSubtitle)) { $defaultSubtitle = $configSubtitle.ToString() }
if (-not [string]::IsNullOrWhiteSpace($configMessage)) { $defaultMessage = $configMessage.ToString() }

$stdinEvent = $null
try {
  if (
    [string]::IsNullOrWhiteSpace($EventJson) -and
    [string]::IsNullOrWhiteSpace($EventFile) -and
    [string]::IsNullOrWhiteSpace($Title) -and
    [Console]::IsInputRedirected
  ) {
    $stdinEvent = [Console]::In.ReadToEnd()
  }
} catch {}

if ([string]::IsNullOrWhiteSpace($EventJson) -and -not [string]::IsNullOrWhiteSpace($EventFile)) {
  try {
    $EventJson = Get-Content -LiteralPath $EventFile -Raw -ErrorAction Stop
  } catch {
    Write-NotifyLog ("eventFile read error: {0}" -f $_.Exception.Message)
  }
}
if ([string]::IsNullOrWhiteSpace($EventJson) -and -not [string]::IsNullOrWhiteSpace($stdinEvent)) { $EventJson = $stdinEvent }

$eventText = $null
if (-not [string]::IsNullOrWhiteSpace($EventJson)) {
  $eventText = $EventJson
} else {
  $eventText = $Title
}

$event = TryParse-JsonLikeString $eventText
$titleWasEvent = ($null -ne $event -and $eventText -eq $Title)

$providerValue = Resolve-Provider $Provider $event
if (
  $Provider -eq "auto" -and
  $providerValue -eq "generic" -and
  -not [string]::IsNullOrWhiteSpace($configProvider)
) {
  $providerValue = Resolve-Provider $configProvider $null
}
$eventType = if ($null -eq $event) { $null } else { (Get-ObjectProperty $event @("type", "eventType", "event_type")) }
$hookEventName = if ($null -eq $event) { $null } else { (Get-ObjectProperty $event @("hook_event_name", "hookEventName")) }
$stopReason = if ($null -eq $event) { $null } else { (Get-ObjectProperty $event @("reason", "stopReason", "stop_reason")) }

# Claude Code hooks: event name is hook_event_name; only fall back to it when Subtitle isn't configured.
if (
  [string]::IsNullOrWhiteSpace($eventType) -and
  [string]::IsNullOrWhiteSpace($configSubtitle) -and
  -not [string]::IsNullOrWhiteSpace($hookEventName)
) {
  $eventType = $hookEventName.ToString()
}

if ($null -ne $event) {
  $inputPreview = $null
  try {
    $inputs = Get-ObjectProperty $event @("input-messages", "input_messages", "inputMessages")
    if ($inputs -is [System.Collections.IEnumerable] -and -not ($inputs -is [string])) {
      $inputPreview = Get-FirstLine ($inputs | Select-Object -First 1)
    } elseif ($inputs -is [string]) {
      $inputPreview = Get-FirstLine $inputs
    }
  } catch {}

  $eventTitle = Get-ObjectProperty $event @("title", "notificationTitle", "notifyTitle")
  $eventSubtitle = Get-ObjectProperty $event @("subtitle", "notificationSubtitle", "notifySubtitle")
  $eventMessage = Get-ObjectProperty $event @("message", "detail", "details")

  if ($titleWasEvent -or [string]::IsNullOrWhiteSpace($Title)) {
    if (-not [string]::IsNullOrWhiteSpace($eventTitle)) {
      $Title = $eventTitle.ToString()
    } elseif (-not [string]::IsNullOrWhiteSpace($configTitle)) {
      $Title = $configTitle.ToString()
    } elseif ($providerValue -eq "codex") {
      $Title = "Codex"
    } elseif ($providerValue -eq "claudecode") {
      $Title = "Claude Code"
    } else {
      $Title = $defaultTitle
    }
  }

  if ([string]::IsNullOrWhiteSpace($Subtitle)) {
    if (-not [string]::IsNullOrWhiteSpace($eventSubtitle)) {
      $Subtitle = $eventSubtitle.ToString()
    } elseif ($providerValue -eq "codex" -and $eventType -eq "agent-turn-complete") {
      $doneText = $defaultSubtitle
      $Subtitle = if ([string]::IsNullOrWhiteSpace($inputPreview)) { $doneText } else { "$($doneText): $inputPreview" }
    } elseif (-not [string]::IsNullOrWhiteSpace($eventType)) {
      $Subtitle = $eventType.ToString()
    } else {
      $Subtitle = $defaultSubtitle
    }
  }

  if ([string]::IsNullOrWhiteSpace($Message)) {
    if (-not [string]::IsNullOrWhiteSpace($eventMessage)) {
      $Message = $eventMessage.ToString()
    } elseif (
      $providerValue -eq "claudecode" -and
      -not [string]::IsNullOrWhiteSpace($stopReason) -and
      [string]::IsNullOrWhiteSpace($configMessage)
    ) {
      $Message = $stopReason.ToString()
    } else {
      $Message = $defaultMessage
    }
  }

  $reasonPreview = if ([string]::IsNullOrWhiteSpace($stopReason)) { "" } else { (Truncate-Text $stopReason.ToString() 120) }
  Write-NotifyLog ("parsed event provider={0} type={1} hook={2} reason={3}" -f $providerValue, $eventType, $hookEventName, $reasonPreview)
} else {
  if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = Get-NotifyEnvValue "AI_CHAT_NOTIFY_TITLE" @("CODEX_NOTIFY_TITLE")
    if ([string]::IsNullOrWhiteSpace($Title) -and -not [string]::IsNullOrWhiteSpace($configTitle)) { $Title = $configTitle.ToString() }
  }
  if ([string]::IsNullOrWhiteSpace($Subtitle)) {
    $Subtitle = Get-NotifyEnvValue "AI_CHAT_NOTIFY_SUBTITLE" @("CODEX_NOTIFY_SUBTITLE")
    if ([string]::IsNullOrWhiteSpace($Subtitle) -and -not [string]::IsNullOrWhiteSpace($configSubtitle)) { $Subtitle = $configSubtitle.ToString() }
  }
  if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = Get-NotifyEnvValue "AI_CHAT_NOTIFY_MESSAGE" @("CODEX_NOTIFY_MESSAGE")
    if ([string]::IsNullOrWhiteSpace($Message) -and -not [string]::IsNullOrWhiteSpace($configMessage)) { $Message = $configMessage.ToString() }
  }
}

$titleOverride = Get-NotifyEnvValue "AI_CHAT_NOTIFY_TITLE" @("CODEX_NOTIFY_TITLE")
$subtitleOverride = Get-NotifyEnvValue "AI_CHAT_NOTIFY_SUBTITLE" @("CODEX_NOTIFY_SUBTITLE")
$messageOverride = Get-NotifyEnvValue "AI_CHAT_NOTIFY_MESSAGE" @("CODEX_NOTIFY_MESSAGE")
if (-not [string]::IsNullOrWhiteSpace($titleOverride)) { $Title = $titleOverride }
if (-not [string]::IsNullOrWhiteSpace($subtitleOverride)) { $Subtitle = $subtitleOverride }
if (-not [string]::IsNullOrWhiteSpace($messageOverride)) { $Message = $messageOverride }

if ([string]::IsNullOrWhiteSpace($Title)) { $Title = $defaultTitle }
if ([string]::IsNullOrWhiteSpace($Subtitle)) { $Subtitle = $defaultSubtitle }
if ([string]::IsNullOrWhiteSpace($Message)) { $Message = $defaultMessage }

$Title = Truncate-Text $Title 60
$Subtitle = Truncate-Text $Subtitle 120
$Message = Truncate-Text $Message 200

$methodValue = $Method
if ([string]::IsNullOrWhiteSpace($methodValue)) { $methodValue = Get-NotifyEnvValue "AI_CHAT_NOTIFY_METHOD" @("CODEX_NOTIFY_METHOD") }
if ([string]::IsNullOrWhiteSpace($methodValue) -and $null -ne $event) {
  $eventMethod = Get-ObjectProperty $event @("method", "notifyMethod", "notify_method")
  if (-not [string]::IsNullOrWhiteSpace($eventMethod)) { $methodValue = $eventMethod.ToString() }
}
if ([string]::IsNullOrWhiteSpace($methodValue) -and -not [string]::IsNullOrWhiteSpace($configMethod)) {
  $methodValue = $configMethod.ToString()
}
if ([string]::IsNullOrWhiteSpace($methodValue)) {
  if (Test-ToastNotificationsEnabled) { $methodValue = "balloon" } else { $methodValue = "popup" }
}
$methodValue = $methodValue.Trim().ToLowerInvariant()
if ($methodValue -ne "popup") { $methodValue = "balloon" }

$durationRaw = $null
if ($PSBoundParameters.ContainsKey("DurationSeconds")) {
  $durationRaw = $DurationSeconds
} else {
  $durationRaw = Get-NotifyEnvValue "AI_CHAT_NOTIFY_DURATION_SECONDS" @("AI_CHAT_NOTIFY_DURATION_SEC", "CODEX_NOTIFY_DURATION_SECONDS", "CODEX_NOTIFY_DURATION_SEC")
  if ([string]::IsNullOrWhiteSpace($durationRaw) -and $null -ne $event) {
    $eventDuration = Get-ObjectProperty $event @("durationSeconds", "duration_seconds", "duration", "seconds")
    if ($null -ne $eventDuration) { $durationRaw = $eventDuration }
  }
  if ([string]::IsNullOrWhiteSpace($durationRaw) -and $null -ne $configDurationSeconds) {
    $durationRaw = $configDurationSeconds
  }
  if ([string]::IsNullOrWhiteSpace($durationRaw)) {
    $durationRaw = if ($methodValue -eq "popup") { 0 } else { 5 }
  }
}
try { $durationValue = [int]$durationRaw } catch { $durationValue = 5 }
if ($durationValue -lt 0) { $durationValue = 0 }
if ($durationValue -gt 120) { $durationValue = 120 }
if ($methodValue -ne "popup" -and $durationValue -lt 1) { $durationValue = 5 }

$noSoundValue = $false
if ($PSBoundParameters.ContainsKey("NoSound")) {
  $noSoundValue = [bool]$NoSound
} else {
  $noSoundEnv = Get-NotifyEnvValue "AI_CHAT_NOTIFY_NOSOUND" @("CODEX_NOTIFY_NOSOUND")
  if (-not [string]::IsNullOrWhiteSpace($noSoundEnv)) {
    $noSoundValue = Test-Truthy $noSoundEnv
  } elseif ($null -ne $event) {
    $eventNoSound = Get-ObjectProperty $event @("noSound", "nosound", "no_sound", "silent")
    $noSoundValue = Test-Truthy $eventNoSound
  } elseif ($null -ne $configNoSound) {
    $noSoundValue = Test-Truthy $configNoSound
  }
}

Write-NotifyLog ("toastEnabled={0} method={1} durationSeconds={2} noSound={3}" -f (Test-ToastNotificationsEnabled), $methodValue, $durationValue, $noSoundValue)

$env:AI_CHAT_NOTIFY_TITLE = $Title
$env:AI_CHAT_NOTIFY_SUBTITLE = $Subtitle
$env:AI_CHAT_NOTIFY_MESSAGE = $Message
$env:AI_CHAT_NOTIFY_METHOD = $methodValue
$env:AI_CHAT_NOTIFY_DURATION_SECONDS = $durationValue
$env:AI_CHAT_NOTIFY_NOSOUND = if ($noSoundValue) { "1" } else { "0" }
if (-not [string]::IsNullOrWhiteSpace($script:NotifyLogPath)) { $env:AI_CHAT_NOTIFY_LOG = $script:NotifyLogPath }
if (-not [string]::IsNullOrWhiteSpace($configPathValue)) { $env:AI_CHAT_NOTIFY_CONFIG_PATH = $configPathValue }

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$innerPath = Join-Path $scriptRoot "ai-chat-notify-inner.ps1"

$pwshCmd = Get-Command "pwsh" -ErrorAction SilentlyContinue
$powershellCmd = Get-Command "powershell" -ErrorAction SilentlyContinue
$psExe = if ($pwshCmd) { $pwshCmd.Source } elseif ($powershellCmd) { $powershellCmd.Source } else { $null }

try {
  if ($psExe -and (Test-Path -LiteralPath $innerPath)) {
    Start-Process -FilePath $psExe -ArgumentList @(
      "-NoProfile",
      "-NoLogo",
      "-STA",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      $innerPath
    ) -WindowStyle Hidden | Out-Null
  } else {
    Write-NotifyLog "inner script missing or no PowerShell found; skipped"
  }
} catch {
  Write-NotifyLog ("start-process error: {0}" -f $_.Exception.Message)
  # Always succeed.
}

exit 0
