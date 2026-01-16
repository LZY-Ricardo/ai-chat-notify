[CmdletBinding()]
param(
  [AllowNull()][string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

function Ensure-STA {
  try {
    if ([System.Threading.Thread]::CurrentThread.ApartmentState -eq [System.Threading.ApartmentState]::STA) {
      return
    }
  } catch {}

  $pwshCmd = Get-Command "pwsh" -ErrorAction SilentlyContinue
  $powershellCmd = Get-Command "powershell" -ErrorAction SilentlyContinue
  $psExe = if ($pwshCmd) { $pwshCmd.Source } elseif ($powershellCmd) { $powershellCmd.Source } else { $null }

  if (-not $psExe) { throw "PowerShell not found." }

  $args = @(
    "-NoProfile",
    "-NoLogo",
    "-STA",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $PSCommandPath
  )

  if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $args += @("-ConfigPath", $ConfigPath)
  }

  Start-Process -FilePath $psExe -ArgumentList $args | Out-Null
  exit 0
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

function Load-JsonFile {
  param([AllowNull()][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try {
    return ((Get-Content -LiteralPath $Path -Raw -ErrorAction Stop) | ConvertFrom-Json -ErrorAction Stop)
  } catch {
    return $null
  }
}

function Ensure-Directory {
  param([Parameter(Mandatory = $true)][string]$Path)
  $dir = Split-Path -Parent $Path
  if ([string]::IsNullOrWhiteSpace($dir)) { return }
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
}

function Save-JsonFile {
  param(
    [Parameter(Mandatory = $true)][object]$Object,
    [Parameter(Mandatory = $true)][string]$Path
  )

  Ensure-Directory $Path
  $json = $Object | ConvertTo-Json -Depth 10
  Set-Content -LiteralPath $Path -Encoding UTF8 -Value $json
}

function New-DefaultConfig {
  return [ordered]@{
    version  = 2
    defaults = [ordered]@{
      provider        = "codex"
      title           = "AI Chat"
      subtitle        = "任务已完成"
      message         = "请到 CLI/IDE 中查看详细信息"
      method          = "popup"
      durationSeconds = 2
      noSound         = $true
    }
    providers = [ordered]@{
      codex = [ordered]@{
        title           = "Codex"
        subtitle        = "任务已完成"
        message         = "请到 CLI/IDE 中查看详细信息"
        method          = "popup"
        durationSeconds = 2
        noSound         = $true
        popup           = [ordered]@{
          width               = 360
          minHeight           = 200
          fontFamily          = "Microsoft YaHei UI"
          titleFontSize       = 20
          subtitleFontSize    = 18
          messageFontSize     = 14
          titleColor          = "#111827"
          subtitleColor       = "#111827"
          messageColor        = "#374151"
          backgroundColor     = "#FFFFFF"
          borderColor         = "#E6E8EB"
          dividerColor        = "#EEF0F2"
          accentColor         = "#2B71D8"
          iconText            = "i"
          iconTextColor       = "#FFFFFF"
          iconBackgroundColor = "#2B71D8"
          okText              = "确定"
        }
      }
      claudecode = [ordered]@{
        title           = "Claude Code"
        subtitle        = "Task Complete"
        message         = "Check your CLI/IDE for details."
        method          = "popup"
        durationSeconds = 2
        noSound         = $true
        popup           = [ordered]@{
          width               = 400
          minHeight           = 180
          fontFamily          = "Segoe UI"
          titleFontSize       = 18
          subtitleFontSize    = 16
          messageFontSize     = 13
          titleColor          = "#1F2937"
          subtitleColor       = "#4B5563"
          messageColor        = "#6B7280"
          backgroundColor     = "#FAFAFA"
          borderColor         = "#D1D5DB"
          dividerColor        = "#E5E7EB"
          accentColor         = "#7C3AED"
          iconText            = "C"
          iconTextColor       = "#FFFFFF"
          iconBackgroundColor = "#7C3AED"
          okText              = "OK"
        }
      }
    }
    popup    = [ordered]@{
      width               = 360
      minHeight           = 200
      fontFamily          = "Microsoft YaHei UI"
      titleFontSize       = 20
      subtitleFontSize    = 18
      messageFontSize     = 14
      titleColor          = "#111827"
      subtitleColor       = "#111827"
      messageColor        = "#374151"
      backgroundColor     = "#FFFFFF"
      borderColor         = "#E6E8EB"
      dividerColor        = "#EEF0F2"
      accentColor         = "#2B71D8"
      iconText            = "i"
      iconTextColor       = "#FFFFFF"
      iconBackgroundColor = "#2B71D8"
      okText              = "确定"
    }
  }
}

function Migrate-ConfigToV2 {
  param([Parameter(Mandatory = $true)][object]$V1Config)

  try {
    $v1 = $V1Config
    $defaults = if ($null -ne $v1.defaults) { $v1.defaults } else { @{} }
    $popup = if ($null -ne $v1.popup) { $v1.popup } else { @{} }

    # Determine the primary provider from defaults
    $providerRaw = if ($null -ne $defaults.provider) { $defaults.provider.ToString() } else { "codex" }
    $provider = $providerRaw.Trim().ToLowerInvariant()
    if ($provider -eq "claude-code" -or $provider -eq "claude_code" -or $provider -eq "claude") { $provider = "claudecode" }
    if ($provider -ne "codex" -and $provider -ne "claudecode") { $provider = "codex" }

    # Create provider-specific config from v1 settings
    $providerConfig = [ordered]@{
      title           = if ($null -ne $defaults.title) { $defaults.title.ToString() } else { "AI Chat" }
      subtitle        = if ($null -ne $defaults.subtitle) { $defaults.subtitle.ToString() } else { "任务已完成" }
      message         = if ($null -ne $defaults.message) { $defaults.message.ToString() } else { "请到 CLI/IDE 中查看详细信息" }
      method          = if ($null -ne $defaults.method) { $defaults.method.ToString() } else { "popup" }
      durationSeconds = if ($null -ne $defaults.durationSeconds) { [int]$defaults.durationSeconds } else { 2 }
      noSound         = if ($null -ne $defaults.noSound) { [bool]$defaults.noSound } else { $true }
      popup           = $popup
    }

    # Create providers object with both codex and claudecode
    $providers = [ordered]@{
      codex = [ordered]@{
        title           = "Codex"
        subtitle        = "任务已完成"
        message         = "请到 CLI/IDE 中查看详细信息"
        method          = "popup"
        durationSeconds = 2
        noSound         = $true
        popup           = Copy-PopupConfig $popup
      }
      claudecode = [ordered]@{
        title           = "Claude Code"
        subtitle        = "Task Complete"
        message         = "Check your CLI/IDE for details."
        method          = "popup"
        durationSeconds = 2
        noSound         = $true
        popup           = Copy-PopupConfig $popup
      }
    }

    # Override the primary provider with v1 settings
    $providers[$provider] = $providerConfig

    # Build v2 config
    return [ordered]@{
      version  = 2
      defaults = [ordered]@{
        provider        = $provider
        title           = "AI Chat"
        subtitle        = "任务已完成"
        message         = "请到 CLI/IDE 中查看详细信息"
        method          = "popup"
        durationSeconds = 2
        noSound         = $true
      }
      providers = $providers
      popup    = $popup
    }
  } catch {
    return $null
  }
}

function Copy-PopupConfig {
  param([Parameter(Mandatory = $true)][object]$Popup)

  return [ordered]@{
    width               = if ($null -ne $Popup.width) { [int]$Popup.width } else { 360 }
    minHeight           = if ($null -ne $Popup.minHeight) { [int]$Popup.minHeight } else { 200 }
    fontFamily          = if ($null -ne $Popup.fontFamily) { $Popup.fontFamily.ToString() } else { "Microsoft YaHei UI" }
    titleFontSize       = if ($null -ne $Popup.titleFontSize) { [double]$Popup.titleFontSize } else { 20 }
    subtitleFontSize    = if ($null -ne $Popup.subtitleFontSize) { [double]$Popup.subtitleFontSize } else { 18 }
    messageFontSize     = if ($null -ne $Popup.messageFontSize) { [double]$Popup.messageFontSize } else { 14 }
    titleColor          = if ($null -ne $Popup.titleColor) { $Popup.titleColor.ToString() } else { "#111827" }
    subtitleColor       = if ($null -ne $Popup.subtitleColor) { $Popup.subtitleColor.ToString() } else { "#111827" }
    messageColor        = if ($null -ne $Popup.messageColor) { $Popup.messageColor.ToString() } else { "#374151" }
    backgroundColor     = if ($null -ne $Popup.backgroundColor) { $Popup.backgroundColor.ToString() } else { "#FFFFFF" }
    borderColor         = if ($null -ne $Popup.borderColor) { $Popup.borderColor.ToString() } else { "#E6E8EB" }
    dividerColor        = if ($null -ne $Popup.dividerColor) { $Popup.dividerColor.ToString() } else { "#EEF0F2" }
    accentColor         = if ($null -ne $Popup.accentColor) { $Popup.accentColor.ToString() } else { "#2B71D8" }
    iconText            = if ($null -ne $Popup.iconText) { $Popup.iconText.ToString() } else { "i" }
    iconTextColor       = if ($null -ne $Popup.iconTextColor) { $Popup.iconTextColor.ToString() } else { "#FFFFFF" }
    iconBackgroundColor = if ($null -ne $Popup.iconBackgroundColor) { $Popup.iconBackgroundColor.ToString() } else { "#2B71D8" }
    okText              = if ($null -ne $Popup.okText) { $Popup.okText.ToString() } else { "确定" }
  }
}

function Normalize-HexColor {
  param([AllowNull()][string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  $t = $Text.Trim()
  if (-not $t.StartsWith("#")) { $t = "#$t" }
  return $t
}

function TryParse-Int {
  param([AllowNull()][string]$Text, [int]$DefaultValue)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $DefaultValue }
  $v = 0
  if ([int]::TryParse($Text.Trim(), [ref]$v)) { return $v }
  return $DefaultValue
}

function TryParse-Double {
  param([AllowNull()][string]$Text, [double]$DefaultValue)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $DefaultValue }
  $v = 0.0
  if ([double]::TryParse($Text.Trim(), [ref]$v)) { return $v }
  return $DefaultValue
}

function Get-DefaultCodexConfigPath {
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
      return (Join-Path (Join-Path $env:USERPROFILE ".codex") "config.toml")
    }
  } catch {}
  return $null
}

function Get-ClaudeUserSettingsPath {
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
      return (Join-Path (Join-Path $env:USERPROFILE ".claude") "settings.json")
    }
  } catch {}
  return $null
}

function Get-ClaudeProjectSettingsLocalPath {
  try {
    $cwd = (Get-Location).Path
    if (-not [string]::IsNullOrWhiteSpace($cwd)) {
      return (Join-Path (Join-Path $cwd ".claude") "settings.local.json")
    }
  } catch {}
  return $null
}

function Get-DefaultClaudeSettingsPath {
  param([ValidateSet("project", "global")][string]$Scope = "project")
  if ($Scope -eq "global") { return Get-ClaudeUserSettingsPath }
  return Get-ClaudeProjectSettingsLocalPath
}

function Normalize-WindowsPath {
  param([AllowNull()][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
  $p = $Path
  if ($p.StartsWith("\\\\")) {
    return ("\\\\" + ($p.Substring(2) -replace '\\\\+', '\\'))
  }
  return ($p -replace '\\\\+', '\\')
}

function Convert-ToForwardSlashPath {
  param([AllowNull()][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  return ($Path -replace '\\', '/')
}

function Quote-TomlString {
  param([AllowNull()][string]$Text)
  if ($null -eq $Text) { $Text = '' }
  $escaped = $Text.Replace('\', '\\').Replace('"', '\"')
  return '"' + $escaped + '"'
}

function Resolve-AiChatNotifyCmdPath {
  $candidates = @()
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
      $candidates += (Join-Path (Join-Path (Join-Path $env:LOCALAPPDATA "ai-chat-notify") "bin") "ai-chat-notify.cmd")
    }
  } catch {}
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
      $candidates += (Join-Path (Join-Path (Join-Path $env:USERPROFILE ".ai-chat-notify") "bin") "ai-chat-notify.cmd")
    }
  } catch {}

  $candidates += @(
    (Join-Path $repoRoot "ai-chat-notify.cmd"),
    (Join-Path (Join-Path $repoRoot "scripts") "ai-chat-notify.cmd")
  )

  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }

  return ($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
}

function Resolve-AiChatNotifyPs1Path {
  $candidates = @()
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
      $candidates += (Join-Path (Join-Path (Join-Path $env:LOCALAPPDATA "ai-chat-notify") "bin") "ai-chat-notify.ps1")
    }
  } catch {}
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
      $candidates += (Join-Path (Join-Path (Join-Path $env:USERPROFILE ".ai-chat-notify") "bin") "ai-chat-notify.ps1")
    }
  } catch {}

  $candidates += @(
    (Join-Path (Join-Path $repoRoot "scripts") "ai-chat-notify.ps1"),
    (Join-Path $repoRoot "ai-chat-notify.ps1")
  )

  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }

  return ($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
}

function Build-CodexNotifyLine {
  param(
    [Parameter(Mandatory = $true)][string]$NotifyPs1Path,
    [AllowNull()][string]$ConfigPathToUse,
    [AllowNull()][string]$LogPathToUse
  )

  $ps1 = Convert-ToForwardSlashPath $NotifyPs1Path
  $cfg = Convert-ToForwardSlashPath $ConfigPathToUse
  $log = Convert-ToForwardSlashPath $LogPathToUse

  $argv = New-Object System.Collections.Generic.List[string]
  $argv.Add("powershell.exe")
  $argv.Add("-NoProfile")
  $argv.Add("-ExecutionPolicy")
  $argv.Add("Bypass")
  $argv.Add("-File")
  $argv.Add($ps1)
  if (-not [string]::IsNullOrWhiteSpace($cfg)) {
    $argv.Add("-ConfigPath")
    $argv.Add($cfg)
  }
  if (-not [string]::IsNullOrWhiteSpace($log)) {
    $argv.Add("-LogPath")
    $argv.Add($log)
  }
  # Codex 会在最后追加 JSON 参数；这里预放一个 -EventJson 以便 PowerShell 正确绑定值（避免 cmd.exe 的二次解析导致 JSON 丢失/拆分）。
  $argv.Add("-EventJson")

  $quoted = @()
  foreach ($a in $argv) { $quoted += (Quote-TomlString $a) }
  return ('notify = [' + ($quoted -join ", ") + ']')
}

function Upsert-NotifyInTomlText {
  param(
    [Parameter(Mandatory = $true)][string]$TomlText,
    [Parameter(Mandatory = $true)][string]$NotifyLine
  )

  $newline = if ($TomlText -match "`r`n") { "`r`n" } else { "`n" }
  $lines = $TomlText -split "`r?`n", -1

  $start = -1
  $indent = ""
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^(\s*)notify\s*=') {
      $start = $i
      $indent = $Matches[1]
      break
    }
  }

  if ($start -ge 0) {
    $end = $start
    if ($lines[$start] -match '^\s*notify\s*=\s*\[' -and $lines[$start] -notmatch '\]') {
      while ($end -lt ($lines.Count - 1)) {
        if ($lines[$end] -match '\]') { break }
        $end++
      }
    }

    $before = if ($start -gt 0) { $lines[0..($start - 1)] } else { @() }
    $after = if ($end -lt ($lines.Count - 1)) { $lines[($end + 1)..($lines.Count - 1)] } else { @() }
    return (@($before + @($indent + $NotifyLine) + $after) -join $newline)
  }

  $insertAt = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[') { $insertAt = $i; break }
  }
  if ($insertAt -lt 0) { $insertAt = $lines.Count }

  $before = if ($insertAt -gt 0) { $lines[0..($insertAt - 1)] } else { @() }
  $after = if ($insertAt -lt $lines.Count) { $lines[$insertAt..($lines.Count - 1)] } else { @() }

  $newLines = @()
  $newLines += $before
  if ($before.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($before[-1])) { $newLines += "" }
  $newLines += $NotifyLine
  if ($after.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($after[0])) { $newLines += "" }
  $newLines += $after

  return ($newLines -join $newline)
}

Ensure-STA

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null

$repoRoot = Split-Path -Parent $PSCommandPath

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = $env:AI_CHAT_NOTIFY_CONFIG_PATH
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = $env:CODEX_NOTIFY_CONFIG_PATH
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = Get-DefaultConfigPath
}

$loaded = Load-JsonFile $ConfigPath
$config = if ($null -eq $loaded) { New-DefaultConfig } else { $loaded }

# Auto-migrate v1 config to v2
$configVersion = if ($null -ne $config.version) { [int]$config.version } else { 1 }
if ($configVersion -lt 2) {
  $migrated = Migrate-ConfigToV2 $config
  if ($null -ne $migrated) {
    $config = $migrated
    # Auto-save migrated config
    try {
      Save-JsonFile $config $ConfigPath
    } catch {}
  }
}

# Store current config globally for use in Read-UIToConfig
$script:CurrentConfig = $config

if ($null -eq $config.defaults) { $config | Add-Member -NotePropertyName defaults -NotePropertyValue @{} }
if ($null -eq $config.popup) { $config | Add-Member -NotePropertyName popup -NotePropertyValue @{} }
if ($null -eq $config.providers) { $config | Add-Member -NotePropertyName providers -NotePropertyValue @{} }

$xaml = @'
<Window
  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="ai-chat-notify 配置器"
  Width="860"
  Height="640"
  WindowStartupLocation="CenterScreen"
  FontFamily="Microsoft YaHei UI">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto" />
      <RowDefinition Height="*" />
      <RowDefinition Height="Auto" />
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center">
      <TextBlock Text="配置文件：" VerticalAlignment="Center" />
      <TextBox x:Name="ConfigPathBox" Width="520" Margin="8,0,0,0" />
      <Button x:Name="OpenConfigDirBtn" Content="打开目录" Margin="8,0,0,0" Padding="10,6" />
      <Button x:Name="ReloadBtn" Content="重新加载" Margin="8,0,0,0" Padding="10,6" />
    </StackPanel>

    <TabControl x:Name="MainTabs" Grid.Row="1" Margin="0,12,0,12">
      <TabItem x:Name="BasicTabItem" Header="基础">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <Grid Margin="12">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
            </Grid.RowDefinitions>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="120" />
              <ColumnDefinition Width="*" />
              <ColumnDefinition Width="120" />
              <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>

            <TextBlock Grid.Row="0" Grid.Column="0" Text="Provider" VerticalAlignment="Center" />
            <ComboBox x:Name="ProviderBox" Grid.Row="0" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="0" Grid.Column="2" Text="方式" VerticalAlignment="Center" />
            <ComboBox x:Name="MethodBox" Grid.Row="0" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="1" Grid.Column="0" Text="时长(秒)" VerticalAlignment="Center" />
            <TextBox x:Name="DurationBox" Grid.Row="1" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="1" Grid.Column="2" Text="静音" VerticalAlignment="Center" />
            <CheckBox x:Name="NoSoundBox" Grid.Row="1" Grid.Column="3" Margin="8,2,0,2" VerticalAlignment="Center" />

            <TextBlock Grid.Row="2" Grid.Column="0" Text="Title" VerticalAlignment="Center" />
            <TextBox x:Name="TitleBox" Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="3" Grid.Column="0" Text="Subtitle" VerticalAlignment="Center" />
            <TextBox x:Name="SubtitleBox" Grid.Row="3" Grid.Column="1" Grid.ColumnSpan="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="4" Grid.Column="0" Text="Message" VerticalAlignment="Top" Margin="0,6,0,0" />
            <TextBox x:Name="MessageBox" Grid.Row="4" Grid.Column="1" Grid.ColumnSpan="3" Margin="8,2,0,2"
              Height="120" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" />

            <StackPanel Grid.Row="5" Grid.Column="0" Grid.ColumnSpan="4" Orientation="Horizontal" Margin="0,10,0,0">
              <Button x:Name="TestPopupBtn" Content="测试 Popup" Padding="12,8" />
              <Button x:Name="TestBalloonBtn" Content="测试 Balloon" Padding="12,8" Margin="10,0,0,0" />
            </StackPanel>

            <Grid Grid.Row="6" Grid.Column="0" Grid.ColumnSpan="4" Margin="0,12,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
              </Grid.ColumnDefinitions>
              <TextBlock Grid.Column="0" Foreground="#6B7280" TextWrapping="Wrap"
                Text="新手流程：先调整文案并测试预览 → 右下角保存配置 → 到“安装/集成”页接入 Codex/Claude（写入后重启对应客户端生效）。" />
              <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="12,0,0,0">
                <Button x:Name="GoCodexTabBtn" Content="去配置 Codex" Padding="12,8"
                  ToolTip="跳转到“安装/集成”页的 Codex 集成区域" />
                <Button x:Name="GoClaudeTabBtn" Content="去配置 Claude" Padding="12,8" Margin="10,0,0,0"
                  ToolTip="跳转到“安装/集成”页的 Claude Code 集成区域" />
              </StackPanel>
            </Grid>
          </Grid>
        </ScrollViewer>
      </TabItem>

      <TabItem x:Name="PopupStyleTabItem" Header="样式（Popup）">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <Grid Margin="12">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="160" />
              <ColumnDefinition Width="*" />
              <ColumnDefinition Width="160" />
              <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
              <RowDefinition Height="Auto" />
            </Grid.RowDefinitions>

            <TextBlock Grid.Row="0" Grid.Column="0" Text="宽度" VerticalAlignment="Center" />
            <TextBox x:Name="PopupWidthBox" Grid.Row="0" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="0" Grid.Column="2" Text="最小高度" VerticalAlignment="Center" />
            <TextBox x:Name="PopupMinHeightBox" Grid.Row="0" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="1" Grid.Column="0" Text="字体" VerticalAlignment="Center" />
            <TextBox x:Name="FontFamilyBox" Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="2" Grid.Column="0" Text="Title 字号" VerticalAlignment="Center" />
            <TextBox x:Name="TitleFontSizeBox" Grid.Row="2" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="2" Grid.Column="2" Text="Subtitle 字号" VerticalAlignment="Center" />
            <TextBox x:Name="SubtitleFontSizeBox" Grid.Row="2" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="3" Grid.Column="0" Text="Message 字号" VerticalAlignment="Center" />
            <TextBox x:Name="MessageFontSizeBox" Grid.Row="3" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="3" Grid.Column="2" Text="确定按钮文案" VerticalAlignment="Center" />
            <TextBox x:Name="OkTextBox" Grid.Row="3" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="4" Grid.Column="0" Text="Title 颜色" VerticalAlignment="Center" />
            <TextBox x:Name="TitleColorBox" Grid.Row="4" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="4" Grid.Column="2" Text="Subtitle 颜色" VerticalAlignment="Center" />
            <TextBox x:Name="SubtitleColorBox" Grid.Row="4" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="5" Grid.Column="0" Text="Message 颜色" VerticalAlignment="Center" />
            <TextBox x:Name="MessageColorBox" Grid.Row="5" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="5" Grid.Column="2" Text="背景色" VerticalAlignment="Center" />
            <TextBox x:Name="BackgroundColorBox" Grid.Row="5" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="6" Grid.Column="0" Text="边框色" VerticalAlignment="Center" />
            <TextBox x:Name="BorderColorBox" Grid.Row="6" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="6" Grid.Column="2" Text="分割线色" VerticalAlignment="Center" />
            <TextBox x:Name="DividerColorBox" Grid.Row="6" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="7" Grid.Column="0" Text="强调色(按钮)" VerticalAlignment="Center" />
            <TextBox x:Name="AccentColorBox" Grid.Row="7" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="7" Grid.Column="2" Text="图标文字" VerticalAlignment="Center" />
            <TextBox x:Name="IconTextBox" Grid.Row="7" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="8" Grid.Column="0" Text="图标文字色" VerticalAlignment="Center" />
            <TextBox x:Name="IconTextColorBox" Grid.Row="8" Grid.Column="1" Margin="8,2,18,2" />
            <TextBlock Grid.Row="8" Grid.Column="2" Text="图标背景色" VerticalAlignment="Center" />
            <TextBox x:Name="IconBgColorBox" Grid.Row="8" Grid.Column="3" Margin="8,2,0,2" />

            <TextBlock Grid.Row="9" Grid.Column="0" Grid.ColumnSpan="4" Margin="0,10,0,0"
              Text="颜色格式支持：#RRGGBB 或 #AARRGGBB" Foreground="#6B7280" />
          </Grid>
        </ScrollViewer>
      </TabItem>

      <TabItem x:Name="SnippetTabItem" Header="集成片段">
        <Grid Margin="12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
          </Grid.RowDefinitions>

          <GroupBox Grid.Row="0" Header="调用位置" Padding="10">
            <StackPanel Orientation="Horizontal">
              <RadioButton x:Name="CmdInstalledRadio" Content="已安装（默认安装目录）" IsChecked="True" Margin="0,0,18,0" />
              <RadioButton x:Name="CmdLocalRadio" Content="本地仓库路径" />
            </StackPanel>
          </GroupBox>

          <GroupBox Grid.Row="1" Header="事件输入方式" Padding="10" Margin="0,10,0,0">
            <StackPanel Orientation="Horizontal">
              <RadioButton x:Name="InputStdinRadio" Content="argv（推荐：末尾追加 JSON）" IsChecked="True" Margin="0,0,18,0" />
              <RadioButton x:Name="InputEventFileRadio" Content="-EventFile" Margin="0,0,18,0" />
              <RadioButton x:Name="InputPositionalRadio" Content="EventJson（从文件读取）" />
            </StackPanel>
          </GroupBox>

          <TextBox x:Name="SnippetBox" Grid.Row="2" Margin="0,10,0,0"
            AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
            IsReadOnly="True" FontFamily="Consolas" FontSize="12" />

          <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="RefreshSnippetBtn" Content="刷新片段" Padding="12,8" />
            <Button x:Name="CopySnippetBtn" Content="复制到剪贴板" Padding="12,8" Margin="10,0,0,0" />
          </StackPanel>
        </Grid>
      </TabItem>

      <TabItem x:Name="InstallTabItem" Header="安装/集成">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12">
            <TextBlock TextWrapping="Wrap" Foreground="#6B7280"
              Text="可选：安装到 PATH（调用 install.ps1 / uninstall.ps1，会修改用户级 PATH，并覆盖安装目录文件）。" />
            <TextBlock Margin="0,6,0,0" TextWrapping="Wrap" Foreground="#6B7280"
              Text="仅用于 Codex 通知时：无需安装到 PATH，直接使用下方“Codex 集成”即可。" />

            <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
              <Button x:Name="InstallBtn" Content="安装/更新到 PATH" Padding="12,8"
                ToolTip="复制脚本到默认安装目录，并（可选）加入用户级 PATH" />
              <Button x:Name="UninstallBtn" Content="卸载并移除 PATH" Padding="12,8" Margin="10,0,0,0"
                ToolTip="删除默认安装目录文件，并从用户级 PATH 移除" />
            </StackPanel>

            <TextBlock Margin="0,12,0,0" TextWrapping="Wrap"
              Text="提示：修改 PATH 需要重启终端生效。安装后可直接使用 ai-chat-notify / ai-chat-notify-config 命令。" />

            <Separator Margin="0,16,0,12" />

            <TextBlock Text="调试（日志）" FontWeight="Bold" />
            <TextBlock Margin="0,6,0,0" TextWrapping="Wrap" Foreground="#6B7280"
              Text="可选：启用 notify 的调试日志（-LogPath）；Codex notify 与 Claude Stop hook 都会复用此设置。" />
            <Grid Margin="0,10,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="120" />
                <ColumnDefinition Width="*" />
              </Grid.ColumnDefinitions>

              <TextBlock Grid.Column="0" Text="调试日志" VerticalAlignment="Center" Margin="0,6,0,0" />
              <Grid Grid.Column="1" Margin="8,6,0,0">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto" />
                  <ColumnDefinition Width="*" />
                  <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>
                <CheckBox x:Name="EnableCodexLogBox" Grid.Column="0" Content="启用（-LogPath）" VerticalAlignment="Center" />
                <TextBox x:Name="CodexLogPathBox" Grid.Column="1" Margin="8,0,8,0"
                  ToolTip="日志文件路径；写入 notify/Stop hook 时会带上 -LogPath" />
                <Button x:Name="OpenCodexLogBtn" Grid.Column="2" Content="打开日志" Padding="10,6"
                  ToolTip="用记事本打开日志文件（不存在会自动创建）" />
              </Grid>
            </Grid>

            <Separator Margin="0,16,0,12" />

            <TextBlock Text="Codex 集成（自动写入 notify 到 config.toml）" FontWeight="Bold" />
            <TextBlock Margin="0,6,0,0" TextWrapping="Wrap" Foreground="#6B7280"
              Text="推荐：点击“保存并写入 notify” → 重启 Codex → 点击“检查 notify”确认已生效。" />
            <Grid Margin="0,10,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="120" />
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
              </Grid.ColumnDefinitions>
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto" />
                <RowDefinition Height="Auto" />
                <RowDefinition Height="Auto" />
              </Grid.RowDefinitions>

              <TextBlock Grid.Row="0" Grid.Column="0" Text="config.toml" VerticalAlignment="Center" />
              <TextBox x:Name="CodexConfigPathBox" Grid.Row="0" Grid.Column="1" Margin="8,2,12,2" />
              <Button x:Name="BrowseCodexConfigBtn" Grid.Row="0" Grid.Column="2" Content="选择..." Padding="10,6" />

              <StackPanel Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
                <Button x:Name="OpenCodexConfigBtn" Content="打开 config.toml" Padding="10,6"
                  ToolTip="在资源管理器中定位 config.toml" />
                <Button x:Name="CheckCodexNotifyBtn" Content="检查 notify" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="检查 config.toml 中的 notify 是否已配置/是否匹配当前配置" />
                <Button x:Name="CopyCodexNotifyBtn" Content="复制 notify" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="复制当前配置器生成的 notify 行（用于手动粘贴到 config.toml）" />
                <Button x:Name="RestoreCodexBackupBtn" Content="恢复最近备份" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="将 config.toml 恢复为最近一次自动备份（会覆盖当前 config.toml）" />
                <Button x:Name="WriteCodexNotifyBtn" Content="保存并写入 notify" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="先保存 config.json，再写入（或覆盖）config.toml 的 notify，并创建 .bak 备份" />
              </StackPanel>

              <TextBlock Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3" Margin="0,8,0,0"
                Foreground="#6B7280" TextWrapping="Wrap"
                Text="会创建 .bak 备份，并覆盖/插入 notify 设置；写入后需重启 Codex 生效。" />
            </Grid>

            <Separator Margin="0,16,0,12" />

            <TextBlock Text="Claude Code 集成（hooks.Stop）" FontWeight="Bold" />
            <TextBlock Margin="0,6,0,0" TextWrapping="Wrap" Foreground="#6B7280"
              Text="推荐：点击“保存并写入 Stop hook” → 重启 Claude Code → 在目标项目目录接受 workspace trust 后跑一轮对话验证。" />
            <Grid Margin="0,10,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="140" />
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
              </Grid.ColumnDefinitions>
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto" />
                <RowDefinition Height="Auto" />
                <RowDefinition Height="Auto" />
                <RowDefinition Height="Auto" />
              </Grid.RowDefinitions>

              <TextBlock Grid.Row="0" Grid.Column="0" Text="写入位置" VerticalAlignment="Center" />
              <StackPanel Grid.Row="0" Grid.Column="1" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="8,2,0,2">
                <RadioButton x:Name="ClaudeScopeProjectRadio" Content="当前项目（.claude/settings.local.json）" IsChecked="True" Margin="0,0,18,0" />
                <RadioButton x:Name="ClaudeScopeGlobalRadio" Content="全局（%USERPROFILE%\\.claude\\settings.json）" />
              </StackPanel>

              <TextBlock Grid.Row="1" Grid.Column="0" Text="设置文件" VerticalAlignment="Center" />
              <TextBox x:Name="ClaudeSettingsPathBox" Grid.Row="1" Grid.Column="1" Margin="8,2,12,2" />
              <Button x:Name="BrowseClaudeSettingsBtn" Grid.Row="1" Grid.Column="2" Content="选择..." Padding="10,6" />

              <StackPanel Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
                <Button x:Name="OpenClaudeSettingsBtn" Content="打开设置文件" Padding="10,6"
                  ToolTip="在资源管理器中定位当前选择的设置文件" />
                <Button x:Name="OpenClaudeDebugBtn" Content="打开 Claude debug" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="打开 %USERPROFILE%\\.claude\\debug（用于确认 hooks 是否匹配/执行）" />
                <Button x:Name="CheckClaudeStopHookBtn" Content="检查 Stop hook" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="检查当前设置文件的 hooks.Stop 中是否已配置 ai-chat-notify 的 Stop hook" />
                <Button x:Name="CopyClaudeStopHookBtn" Content="复制 Stop 片段" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="复制可粘贴到设置文件的 JSON 片段（用于手动合并）" />
                <Button x:Name="RestoreClaudeBackupBtn" Content="恢复最近备份" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="将设置文件恢复为最近一次自动备份（会覆盖当前文件）" />
                <Button x:Name="WriteClaudeStopHookBtn" Content="保存并写入 Stop hook" Padding="10,6" Margin="10,0,0,0"
                  ToolTip="先保存 config.json，再写入（或追加）Stop hook 到设置文件，并创建 .bak 备份" />
              </StackPanel>

              <TextBlock Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="3" Margin="0,8,0,0"
                Foreground="#6B7280" TextWrapping="Wrap"
                Text="写入后需重启 Claude Code 生效；调试日志沿用上方“调试日志（-LogPath）”。注意：Claude Code 不会读取 %USERPROFILE%\\.claude\\settings.local.json（必须写入全局 settings.json 或当前项目 .claude/settings(.local).json）。若 debug 日志提示 workspace trust 未接受，请先在该目录接受信任（否则 hooks 会被跳过）。" />
            </Grid>
          </StackPanel>
        </ScrollViewer>
      </TabItem>
    </TabControl>

    <DockPanel Grid.Row="2">
      <TextBlock x:Name="StatusText" DockPanel.Dock="Left" VerticalAlignment="Center" Foreground="#374151" />
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="SaveBtn" Content="保存配置" Padding="12,8" />
        <Button x:Name="CloseBtn" Content="关闭" Padding="12,8" Margin="10,0,0,0" />
      </StackPanel>
    </DockPanel>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{
  ConfigPathBox       = $window.FindName("ConfigPathBox")
  OpenConfigDirBtn    = $window.FindName("OpenConfigDirBtn")
  ReloadBtn           = $window.FindName("ReloadBtn")
  ProviderBox         = $window.FindName("ProviderBox")
  MethodBox           = $window.FindName("MethodBox")
  DurationBox         = $window.FindName("DurationBox")
  NoSoundBox          = $window.FindName("NoSoundBox")
  TitleBox            = $window.FindName("TitleBox")
  SubtitleBox         = $window.FindName("SubtitleBox")
  MessageBox          = $window.FindName("MessageBox")
  TestPopupBtn        = $window.FindName("TestPopupBtn")
  TestBalloonBtn      = $window.FindName("TestBalloonBtn")
  PopupWidthBox       = $window.FindName("PopupWidthBox")
  PopupMinHeightBox   = $window.FindName("PopupMinHeightBox")
  FontFamilyBox       = $window.FindName("FontFamilyBox")
  TitleFontSizeBox    = $window.FindName("TitleFontSizeBox")
  SubtitleFontSizeBox = $window.FindName("SubtitleFontSizeBox")
  MessageFontSizeBox  = $window.FindName("MessageFontSizeBox")
  OkTextBox           = $window.FindName("OkTextBox")
  TitleColorBox       = $window.FindName("TitleColorBox")
  SubtitleColorBox    = $window.FindName("SubtitleColorBox")
  MessageColorBox     = $window.FindName("MessageColorBox")
  BackgroundColorBox  = $window.FindName("BackgroundColorBox")
  BorderColorBox      = $window.FindName("BorderColorBox")
  DividerColorBox     = $window.FindName("DividerColorBox")
  AccentColorBox      = $window.FindName("AccentColorBox")
  IconTextBox         = $window.FindName("IconTextBox")
  IconTextColorBox    = $window.FindName("IconTextColorBox")
  IconBgColorBox      = $window.FindName("IconBgColorBox")
  CmdInstalledRadio   = $window.FindName("CmdInstalledRadio")
  CmdLocalRadio       = $window.FindName("CmdLocalRadio")
  InputStdinRadio     = $window.FindName("InputStdinRadio")
  InputEventFileRadio = $window.FindName("InputEventFileRadio")
  InputPositionalRadio = $window.FindName("InputPositionalRadio")
  SnippetBox          = $window.FindName("SnippetBox")
  RefreshSnippetBtn   = $window.FindName("RefreshSnippetBtn")
  CopySnippetBtn      = $window.FindName("CopySnippetBtn")
  InstallBtn          = $window.FindName("InstallBtn")
  UninstallBtn        = $window.FindName("UninstallBtn")
  MainTabs            = $window.FindName("MainTabs")
  InstallTabItem      = $window.FindName("InstallTabItem")
  GoCodexTabBtn       = $window.FindName("GoCodexTabBtn")
  GoClaudeTabBtn      = $window.FindName("GoClaudeTabBtn")
  CodexConfigPathBox  = $window.FindName("CodexConfigPathBox")
  BrowseCodexConfigBtn = $window.FindName("BrowseCodexConfigBtn")
  OpenCodexConfigBtn  = $window.FindName("OpenCodexConfigBtn")
  CheckCodexNotifyBtn = $window.FindName("CheckCodexNotifyBtn")
  EnableCodexLogBox   = $window.FindName("EnableCodexLogBox")
  CodexLogPathBox     = $window.FindName("CodexLogPathBox")
  OpenCodexLogBtn     = $window.FindName("OpenCodexLogBtn")
  CopyCodexNotifyBtn  = $window.FindName("CopyCodexNotifyBtn")
  RestoreCodexBackupBtn = $window.FindName("RestoreCodexBackupBtn")
  WriteCodexNotifyBtn = $window.FindName("WriteCodexNotifyBtn")
  ClaudeSettingsPathBox = $window.FindName("ClaudeSettingsPathBox")
  BrowseClaudeSettingsBtn = $window.FindName("BrowseClaudeSettingsBtn")
  ClaudeScopeProjectRadio = $window.FindName("ClaudeScopeProjectRadio")
  ClaudeScopeGlobalRadio  = $window.FindName("ClaudeScopeGlobalRadio")
  OpenClaudeSettingsBtn = $window.FindName("OpenClaudeSettingsBtn")
  OpenClaudeDebugBtn = $window.FindName("OpenClaudeDebugBtn")
  CheckClaudeStopHookBtn = $window.FindName("CheckClaudeStopHookBtn")
  CopyClaudeStopHookBtn = $window.FindName("CopyClaudeStopHookBtn")
  RestoreClaudeBackupBtn = $window.FindName("RestoreClaudeBackupBtn")
  WriteClaudeStopHookBtn = $window.FindName("WriteClaudeStopHookBtn")
  SaveBtn             = $window.FindName("SaveBtn")
  CloseBtn            = $window.FindName("CloseBtn")
  StatusText          = $window.FindName("StatusText")
}

function Set-Status {
  param([string]$Text)
  if ($controls.StatusText) { $controls.StatusText.Text = $Text }
}

function Confirm-Dangerous {
  param(
    [Parameter(Mandatory = $true)][string]$Operation,
    [Parameter(Mandatory = $true)][string]$Impact,
    [AllowNull()][string]$Risk
  )
  $msg = "⚠️ 危险操作检测！`n操作类型：$Operation`n影响范围：$Impact`n风险评估：可能修改你的用户级系统配置（PATH）。`n`n请确认是否继续？"
  if ([string]::IsNullOrWhiteSpace($Risk)) { $Risk = "可能修改你的用户级系统配置。" }
  $msg = "危险操作检测！`n操作类型：$Operation`n影响范围：$Impact`n风险评估：$Risk`n`n请确认是否继续？"
  $result = [System.Windows.MessageBox]::Show($msg, "确认", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
  return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Get-DefaultInstallDir {
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
      return (Join-Path (Join-Path $env:LOCALAPPDATA "ai-chat-notify") "bin")
    }
  } catch {}
  return (Join-Path (Join-Path $env:USERPROFILE ".ai-chat-notify") "bin")
}

function Get-DefaultNotifyLogPath {
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
      return (Join-Path (Join-Path $env:LOCALAPPDATA "ai-chat-notify") "ai-chat-notify.log")
    }
  } catch {}
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
      return (Join-Path (Join-Path $env:USERPROFILE ".ai-chat-notify") "ai-chat-notify.log")
    }
  } catch {}
  return $null
}

function Get-NotifyLogPathFromUI {
  if (-not $controls.EnableCodexLogBox) { return $null }
  if (-not [bool]$controls.EnableCodexLogBox.IsChecked) { return $null }

  $logPath = if ($controls.CodexLogPathBox) { $controls.CodexLogPathBox.Text } else { $null }
  if ([string]::IsNullOrWhiteSpace($logPath)) { $logPath = Get-DefaultNotifyLogPath }
  if (-not [string]::IsNullOrWhiteSpace($logPath)) { $logPath = Normalize-WindowsPath $logPath }
  return $logPath
}

function Open-NotifyLog {
  $logPath = if ($controls.CodexLogPathBox) { $controls.CodexLogPathBox.Text } else { $null }
  if ([string]::IsNullOrWhiteSpace($logPath)) { $logPath = Get-DefaultNotifyLogPath }
  if ([string]::IsNullOrWhiteSpace($logPath)) {
    [System.Windows.MessageBox]::Show("无法确定日志路径。", "错误", "OK", "Error") | Out-Null
    return
  }

  $logPath = Normalize-WindowsPath $logPath
  try {
    Ensure-Directory $logPath
    if (-not (Test-Path -LiteralPath $logPath)) {
      New-Item -ItemType File -Force -Path $logPath | Out-Null
    }
    Start-Process -FilePath "notepad.exe" -ArgumentList @($logPath) | Out-Null
    Set-Status "已打开日志：$logPath"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "打开失败", "OK", "Error") | Out-Null
  }
}

function Update-CodexLogUiState {
  try {
    if (-not $controls.EnableCodexLogBox) { return }
    if (-not $controls.CodexLogPathBox) { return }

    $enabled = [bool]$controls.EnableCodexLogBox.IsChecked
    $controls.CodexLogPathBox.IsEnabled = $enabled

    if ($enabled -and [string]::IsNullOrWhiteSpace($controls.CodexLogPathBox.Text)) {
      $defaultLog = Get-DefaultNotifyLogPath
      if (-not [string]::IsNullOrWhiteSpace($defaultLog)) {
        $controls.CodexLogPathBox.Text = Normalize-WindowsPath $defaultLog
      }
    }
  } catch {}
}

function Save-ConfigFromUI {
  try {
    $pathValue = $controls.ConfigPathBox.Text
    $cfg = Read-UIToConfig
    Save-JsonFile $cfg $pathValue
    Set-Status "已保存：$pathValue"
    return $true
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "保存失败", "OK", "Error") | Out-Null
    return $false
  }
}

function Get-CodexTomlPathFromUI {
  $tomlPath = if ($controls.CodexConfigPathBox) { $controls.CodexConfigPathBox.Text } else { $null }
  if ([string]::IsNullOrWhiteSpace($tomlPath)) {
    $tomlPath = Get-DefaultCodexConfigPath
    if ($controls.CodexConfigPathBox -and -not [string]::IsNullOrWhiteSpace($tomlPath)) {
      $controls.CodexConfigPathBox.Text = Normalize-WindowsPath $tomlPath
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($tomlPath)) { $tomlPath = Normalize-WindowsPath $tomlPath }
  return $tomlPath
}

function Get-NotifyBlockFromTomlText {
  param([Parameter(Mandatory = $true)][string]$TomlText)

  $lines = $TomlText -split "`r?`n", -1
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*notify\s*=') { $start = $i; break }
  }
  if ($start -lt 0) { return $null }

  $end = $start
  if ($lines[$start] -match '^\s*notify\s*=\s*\[' -and $lines[$start] -notmatch '\]') {
    while ($end -lt ($lines.Count - 1)) {
      if ($lines[$end] -match '\]') { break }
      $end++
    }
  }

  return (($lines[$start..$end]) -join "`n")
}

function Open-CodexConfig {
  $tomlPath = Get-CodexTomlPathFromUI
  if ([string]::IsNullOrWhiteSpace($tomlPath)) {
    [System.Windows.MessageBox]::Show("无法确定 Codex 配置文件路径（config.toml）。", "错误", "OK", "Error") | Out-Null
    return
  }
  if (-not (Test-Path -LiteralPath $tomlPath)) {
    [System.Windows.MessageBox]::Show("找不到文件：$tomlPath", "错误", "OK", "Error") | Out-Null
    return
  }

  try {
    $arg = '/select,"' + $tomlPath + '"'
    Start-Process -FilePath "explorer.exe" -ArgumentList @($arg) | Out-Null
    Set-Status "已打开：$tomlPath"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "打开失败", "OK", "Error") | Out-Null
  }
}

function Check-CodexNotify {
  $tomlPath = Get-CodexTomlPathFromUI
  if ([string]::IsNullOrWhiteSpace($tomlPath)) {
    [System.Windows.MessageBox]::Show("无法确定 Codex 配置文件路径（config.toml）。", "错误", "OK", "Error") | Out-Null
    return
  }
  if (-not (Test-Path -LiteralPath $tomlPath)) {
    [System.Windows.MessageBox]::Show("找不到文件：$tomlPath", "错误", "OK", "Error") | Out-Null
    return
  }

  try {
    $text = Get-Content -LiteralPath $tomlPath -Raw -Encoding UTF8 -ErrorAction Stop
    $existing = Get-NotifyBlockFromTomlText -TomlText $text
    if ([string]::IsNullOrWhiteSpace($existing)) {
      Set-Status "未检测到 notify：$tomlPath"
      return
    }

    $notifyPs1Path = Resolve-AiChatNotifyPs1Path
    if ([string]::IsNullOrWhiteSpace($notifyPs1Path) -or -not (Test-Path -LiteralPath $notifyPs1Path)) {
      Set-Status "检查失败：找不到 ai-chat-notify.ps1"
      return
    }

    $configPathToUse = if ($controls.ConfigPathBox) { $controls.ConfigPathBox.Text } else { $null }
    $logPathToUse = Get-NotifyLogPathFromUI
    $expected = Build-CodexNotifyLine -NotifyPs1Path $notifyPs1Path -ConfigPathToUse $configPathToUse -LogPathToUse $logPathToUse

    if ($existing.Trim() -eq $expected.Trim()) {
      Set-Status "notify 已配置并匹配：$tomlPath"
      return
    }

    [System.Windows.MessageBox]::Show(
      "检测到 notify，但与当前配置器生成的不一致。`r`n`r`n当前（config.toml）：`r`n$existing`r`n`r`n期望（当前配置器）：`r`n$expected`r`n`r`n如需更新，请点击 [保存并写入 notify]。",
      "notify 不一致",
      "OK",
      "Warning"
    ) | Out-Null
    Set-Status "notify 不一致：可点击 [保存并写入 notify] 覆盖。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "检查失败", "OK", "Error") | Out-Null
  }
}

function Copy-CodexNotifyLine {
  try {
    $notifyPs1Path = Resolve-AiChatNotifyPs1Path
    if ([string]::IsNullOrWhiteSpace($notifyPs1Path) -or -not (Test-Path -LiteralPath $notifyPs1Path)) {
      [System.Windows.MessageBox]::Show("找不到 ai-chat-notify.ps1。请先安装或在仓库根目录运行配置器。", "错误", "OK", "Error") | Out-Null
      return
    }

    $configPathToUse = if ($controls.ConfigPathBox) { $controls.ConfigPathBox.Text } else { $null }
    $logPathToUse = Get-NotifyLogPathFromUI
    $expected = Build-CodexNotifyLine -NotifyPs1Path $notifyPs1Path -ConfigPathToUse $configPathToUse -LogPathToUse $logPathToUse
    Set-Clipboard -Value $expected
    Set-Status "已复制 notify 行到剪贴板。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "复制失败", "OK", "Error") | Out-Null
  }
}

function Restore-CodexLatestBackup {
  $tomlPath = Get-CodexTomlPathFromUI
  if ([string]::IsNullOrWhiteSpace($tomlPath)) {
    [System.Windows.MessageBox]::Show("无法确定 Codex 配置文件路径（config.toml）。", "错误", "OK", "Error") | Out-Null
    return
  }
  if (-not (Test-Path -LiteralPath $tomlPath)) {
    [System.Windows.MessageBox]::Show("找不到文件：$tomlPath", "错误", "OK", "Error") | Out-Null
    return
  }

  $pattern = $tomlPath + ".bak-*"
  $candidates = @(Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  if (-not $candidates -or $candidates.Count -eq 0) {
    [System.Windows.MessageBox]::Show("未找到备份文件：$pattern", "提示", "OK", "Information") | Out-Null
    Set-Status "未找到备份：$pattern"
    return
  }

  $latest = $candidates[0].FullName
  $impact = $tomlPath
  $risk = "将用备份覆盖当前 config.toml。备份文件：$latest"
  if (-not (Confirm-Dangerous -Operation "恢复 Codex 配置备份" -Impact $impact -Risk $risk)) { return }

  try {
    $preRestoreBackup = Backup-File $tomlPath
    Copy-Item -LiteralPath $latest -Destination $tomlPath -Force -ErrorAction Stop

    $validation = Test-TomlTextValid -Path $tomlPath
    if (-not [bool]$validation.ok) {
      if (-not [string]::IsNullOrWhiteSpace($preRestoreBackup) -and (Test-Path -LiteralPath $preRestoreBackup)) {
        Copy-Item -LiteralPath $preRestoreBackup -Destination $tomlPath -Force -ErrorAction Stop
      }
      $detail = if (-not [string]::IsNullOrWhiteSpace($validation.error)) { "`r`n`r`n$($validation.error)" } else { "" }
      [System.Windows.MessageBox]::Show(
        "恢复后检测到 config.toml 无法被解析，已自动回滚到恢复前的备份。`r`n`r`n使用的校验工具：$($validation.tool)$detail",
        "恢复失败（已回滚）",
        "OK",
        "Error"
      ) | Out-Null
      if (-not [string]::IsNullOrWhiteSpace($preRestoreBackup)) {
        Set-Status "恢复失败：已回滚到恢复前备份：$preRestoreBackup"
      } else {
        Set-Status "恢复失败：无恢复前备份可回滚"
      }
      return
    }

    Set-Status "已恢复备份：$latest（重启 Codex 生效）。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "恢复失败", "OK", "Error") | Out-Null
  }
}

function Save-AndWriteCodexNotify {
  if (-not (Save-ConfigFromUI)) { return }
  $ok = Write-CodexNotify
  if ($ok) { Check-CodexNotify }
}

function Normalize-CommandForCompare {
  param([AllowNull()][string]$Text)
  if ($null -eq $Text) { return "" }
  $t = $Text.Trim()
  $t = $t.Replace('"', '')
  $t = ($t -replace '\\', '/')
  $t = ($t -replace '\s+', ' ')
  try { return $t.ToLowerInvariant() } catch { return $t }
}

function Ensure-ArrayValue {
  param([AllowNull()][object]$Value)
  if ($null -eq $Value) { return @() }
  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) { return @($Value) }
  return @($Value)
}

function Get-ClaudeSettingsScopeFromUI {
  if ($controls.ClaudeScopeGlobalRadio -and [bool]$controls.ClaudeScopeGlobalRadio.IsChecked) { return "global" }
  return "project"
}

function Sync-ClaudeSettingsPathFromScope {
  if (-not $controls.ClaudeSettingsPathBox) { return }
  $scope = Get-ClaudeSettingsScopeFromUI
  $path = Get-DefaultClaudeSettingsPath -Scope $scope
  if (-not [string]::IsNullOrWhiteSpace($path)) {
    $controls.ClaudeSettingsPathBox.Text = Normalize-WindowsPath $path
  }
}

function Get-ClaudeSettingsPathFromUI {
  $settingsPath = if ($controls.ClaudeSettingsPathBox) { $controls.ClaudeSettingsPathBox.Text } else { $null }
  if ([string]::IsNullOrWhiteSpace($settingsPath)) {
    $scope = Get-ClaudeSettingsScopeFromUI
    $settingsPath = Get-DefaultClaudeSettingsPath -Scope $scope
    if ($controls.ClaudeSettingsPathBox -and -not [string]::IsNullOrWhiteSpace($settingsPath)) {
      $controls.ClaudeSettingsPathBox.Text = Normalize-WindowsPath $settingsPath
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($settingsPath)) { $settingsPath = Normalize-WindowsPath $settingsPath }
  return $settingsPath
}

function Open-ClaudeSettings {
  $settingsPath = Get-ClaudeSettingsPathFromUI
  if ([string]::IsNullOrWhiteSpace($settingsPath)) {
    [System.Windows.MessageBox]::Show("无法确定 Claude Code 配置文件路径。", "错误", "OK", "Error") | Out-Null
    return
  }

  try {
    if (-not (Test-Path -LiteralPath $settingsPath)) {
      $dir = Split-Path -Parent $settingsPath
      if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
        Start-Process -FilePath "explorer.exe" -ArgumentList @($dir) | Out-Null
      } else {
        Start-Process -FilePath "explorer.exe" | Out-Null
      }
      Set-Status "未找到文件：$settingsPath"
      return
    }

    $arg = '/select,"' + $settingsPath + '"'
    Start-Process -FilePath "explorer.exe" -ArgumentList @($arg) | Out-Null
    Set-Status "已打开：$settingsPath"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "打开失败", "OK", "Error") | Out-Null
  }
}

function Open-ClaudeDebug {
  try {
    $base = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($base)) {
      Start-Process -FilePath "explorer.exe" | Out-Null
      Set-Status "无法确定 USERPROFILE，已打开资源管理器。"
      return
    }

    $debugDir = Join-Path (Join-Path $base ".claude") "debug"
    if (-not (Test-Path -LiteralPath $debugDir)) {
      $parent = Split-Path -Parent $debugDir
      if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent)) {
        Start-Process -FilePath "explorer.exe" -ArgumentList @($parent) | Out-Null
      } else {
        Start-Process -FilePath "explorer.exe" | Out-Null
      }
      Set-Status "未找到 Claude debug 目录：$debugDir"
      return
    }

    Start-Process -FilePath "explorer.exe" -ArgumentList @($debugDir) | Out-Null
    Set-Status "已打开 Claude debug：$debugDir"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "打开失败", "OK", "Error") | Out-Null
  }
}

function Build-ClaudeStopHookCommand {
  param(
    [Parameter(Mandatory = $true)][string]$NotifyPs1Path,
    [AllowNull()][string]$ConfigPathToUse,
    [AllowNull()][string]$LogPathToUse
  )

  $ps1 = Convert-ToForwardSlashPath $NotifyPs1Path
  $cfg = Convert-ToForwardSlashPath $ConfigPathToUse
  $log = Convert-ToForwardSlashPath $LogPathToUse

  $argv = New-Object System.Collections.Generic.List[string]
  $argv.Add("powershell.exe")
  $argv.Add("-NoProfile")
  $argv.Add("-ExecutionPolicy")
  $argv.Add("Bypass")
  $argv.Add("-File")
  $argv.Add("`"$ps1`"")
  if (-not [string]::IsNullOrWhiteSpace($cfg)) {
    $argv.Add("-ConfigPath")
    $argv.Add("`"$cfg`"")
  }
  if (-not [string]::IsNullOrWhiteSpace($log)) {
    $argv.Add("-LogPath")
    $argv.Add("`"$log`"")
  }
  $argv.Add("-Provider")
  $argv.Add("claudecode")

  return ($argv -join " ")
}

function Build-ClaudeStopHookSnippet {
  param([Parameter(Mandatory = $true)][string]$Command)
  $obj = [ordered]@{
    hooks = [ordered]@{
      Stop = @(
        [ordered]@{
          matcher = "*"
          hooks   = @(
            [ordered]@{
              type    = "command"
              command = $Command
            }
          )
        }
      )
    }
  }
  return ($obj | ConvertTo-Json -Depth 10)
}

function Get-ClaudeStopHookCommandsFromRulesValue {
  param([AllowNull()][object]$RulesValue)
  $rules = Ensure-ArrayValue $RulesValue
  $commands = New-Object System.Collections.Generic.List[string]
  foreach ($rule in $rules) {
    if ($null -eq $rule) { continue }
    $hooksValue = $null
    try { $hooksValue = $rule.hooks } catch {}
    $hooks = Ensure-ArrayValue $hooksValue
    foreach ($h in $hooks) {
      if ($null -eq $h) { continue }
      $typeValue = $null
      $commandValue = $null
      try { $typeValue = $h.type } catch {}
      try { $commandValue = $h.command } catch {}
      if ($null -eq $typeValue -or $null -eq $commandValue) { continue }
      if ($typeValue.ToString().Trim().ToLowerInvariant() -ne "command") { continue }
      $cmd = $commandValue.ToString()
      if (-not [string]::IsNullOrWhiteSpace($cmd)) { $commands.Add($cmd) }
    }
  }
  return @($commands.ToArray())
}

function Get-ClaudeStopHookCommands {
  param([AllowNull()][object]$SettingsObject)
  if ($null -eq $SettingsObject) { return @() }

  $hooksObj = $null
  try {
    $p = $SettingsObject.PSObject.Properties["hooks"]
    if ($null -ne $p) { $hooksObj = $p.Value }
  } catch {}
  if ($null -eq $hooksObj) { return @() }

  $stopValue = $null
  try {
    $p = $hooksObj.PSObject.Properties["Stop"]
    if ($null -ne $p) { $stopValue = $p.Value }
  } catch {}

  return @(Get-ClaudeStopHookCommandsFromRulesValue -RulesValue $stopValue)
}

function Get-ClaudeStopHookCommandsLegacy {
  param([AllowNull()][object]$SettingsObject)
  if ($null -eq $SettingsObject) { return @() }

  $stopValue = $null
  try {
    $p = $SettingsObject.PSObject.Properties["Stop"]
    if ($null -ne $p) { $stopValue = $p.Value }
  } catch {}

  return @(Get-ClaudeStopHookCommandsFromRulesValue -RulesValue $stopValue)
}

function Get-ClaudeStopHookRuleKey {
  param([AllowNull()][object]$Rule)
  if ($null -eq $Rule) { return "" }

  $matcher = ""
  try { if ($null -ne $Rule.matcher) { $matcher = $Rule.matcher.ToString() } } catch {}

  $cmds = @(Get-ClaudeStopHookCommandsFromRulesValue -RulesValue @($Rule) | ForEach-Object { Normalize-CommandForCompare $_ })
  $cmds = @($cmds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
  if ($cmds.Count -gt 0) {
    $m = $matcher.Trim()
    try { $m = $m.ToLowerInvariant() } catch {}
    return ($m + "|" + ($cmds -join ";"))
  }

  try { return ($Rule | ConvertTo-Json -Depth 10 -Compress) } catch { return "" }
}

function Test-JsonTextValid {
  param([Parameter(Mandatory = $true)][string]$Path)
  try {
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $null = ($raw | ConvertFrom-Json -ErrorAction Stop)
    return [ordered]@{ ok = $true; tool = "ConvertFrom-Json"; error = "" }
  } catch {
    return [ordered]@{ ok = $false; tool = "ConvertFrom-Json"; error = $_.Exception.Message }
  }
}

function Check-ClaudeStopHook {
  $settingsPath = Get-ClaudeSettingsPathFromUI
  if ([string]::IsNullOrWhiteSpace($settingsPath)) {
    [System.Windows.MessageBox]::Show("无法确定 Claude Code 配置文件路径。", "错误", "OK", "Error") | Out-Null
    return
  }
  if (-not (Test-Path -LiteralPath $settingsPath)) {
    Set-Status "未找到文件：$settingsPath"
    return
  }

  try {
    $settingsText = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
    $settings = $settingsText | ConvertFrom-Json -ErrorAction Stop

    $hooksObj = $null
    $hooksIsObject = $false
    try {
      $p = $settings.PSObject.Properties["hooks"]
      if ($null -ne $p) { $hooksObj = $p.Value }
      if ($null -ne $hooksObj -and ($hooksObj -is [System.Management.Automation.PSCustomObject] -or $hooksObj -is [hashtable])) {
        $hooksIsObject = $true
      } else {
        $hooksObj = $null
      }
    } catch {}

    $stopValue = $null
    $stopIsArray = $false
    if ($hooksIsObject) {
      try {
        $p = $hooksObj.PSObject.Properties["Stop"]
        if ($null -ne $p) { $stopValue = $p.Value }
        if ($null -ne $stopValue) { $stopIsArray = ($stopValue -is [System.Array]) }
      } catch {}
    }

    $legacyStopValue = $null
    $legacyStopIsArray = $false
    try {
      $p = $settings.PSObject.Properties["Stop"]
      if ($null -ne $p) { $legacyStopValue = $p.Value }
      if ($null -ne $legacyStopValue) { $legacyStopIsArray = ($legacyStopValue -is [System.Array]) }
    } catch {}

    $notifyPs1Path = Resolve-AiChatNotifyPs1Path
    if ([string]::IsNullOrWhiteSpace($notifyPs1Path) -or -not (Test-Path -LiteralPath $notifyPs1Path)) {
      Set-Status "检查失败：找不到 ai-chat-notify.ps1"
      return
    }

    $configPathToUse = if ($controls.ConfigPathBox) { $controls.ConfigPathBox.Text } else { $null }
    $logPathToUse = Get-NotifyLogPathFromUI
    $expected = Build-ClaudeStopHookCommand -NotifyPs1Path $notifyPs1Path -ConfigPathToUse $configPathToUse -LogPathToUse $logPathToUse

    $expectedNorm = Normalize-CommandForCompare $expected
    $existingCommands = @(Get-ClaudeStopHookCommands -SettingsObject $settings)
    $matched = $false
    foreach ($cmd in $existingCommands) {
      if ((Normalize-CommandForCompare $cmd) -eq $expectedNorm) { $matched = $true; break }
    }

    if ($matched) {
      if ($stopIsArray) {
        Set-Status "Stop hook 已配置并匹配（hooks.Stop）：$settingsPath"
        return
      }

      [System.Windows.MessageBox]::Show(
        "检测到 hooks.Stop 命令匹配，但所选设置文件（$settingsPath）的 hooks.Stop 结构不是数组（应为 hooks: { Stop: [ ... ] }）。`r`n`r`nClaude Code 可能不会执行该 hook。`r`n`r`n请点击 [保存并写入 Stop hook] 进行修复。",
        "hooks.Stop 结构不正确",
        "OK",
        "Warning"
      ) | Out-Null
      Set-Status "Stop hook 命令匹配但 hooks.Stop 结构不正确：请点击 [保存并写入 Stop hook] 修复。"
      return
    }

    $legacyCommands = @(Get-ClaudeStopHookCommandsLegacy -SettingsObject $settings)
    $legacyMatched = $false
    foreach ($cmd in $legacyCommands) {
      if ((Normalize-CommandForCompare $cmd) -eq $expectedNorm) { $legacyMatched = $true; break }
    }

    if ($legacyMatched) {
      $tip = if ($legacyStopIsArray) { "" } else { "`r`n`r`n另外：检测到旧版 Stop（顶层）结构不是数组，建议一并修复。" }
      [System.Windows.MessageBox]::Show(
        "检测到旧版 Stop（顶层）命令匹配，但 Claude Code 只识别 hooks.Stop，因此不会执行旧版 Stop。$tip`r`n`r`n请点击 [保存并写入 Stop hook] 自动迁移到 hooks.Stop。",
        "检测到旧版 Stop（需迁移）",
        "OK",
        "Warning"
      ) | Out-Null
      Set-Status "检测到旧版 Stop（顶层）命令匹配：请点击 [保存并写入 Stop hook] 迁移到 hooks.Stop。"
      return
    }

    if ($existingCommands.Count -eq 0 -and $legacyCommands.Count -eq 0) {
      Set-Status "未检测到 Stop hook（hooks.Stop）：$settingsPath"
      return
    }

    $preview = (($existingCommands | Select-Object -First 2) -join "`r`n")
    if ([string]::IsNullOrWhiteSpace($preview) -and $legacyCommands.Count -gt 0) {
      $preview = (($legacyCommands | Select-Object -First 2) -join "`r`n")
    }
    [System.Windows.MessageBox]::Show(
      "检测到 Stop hooks（hooks.Stop 或旧版 Stop），但未匹配当前配置器生成的命令。`r`n`r`n当前（$settingsPath，最多展示2条）：`r`n$preview`r`n`r`n期望（当前配置器）：`r`n$expected`r`n`r`n如需更新，请点击 [保存并写入 Stop hook]。",
      "Stop hook 不一致",
      "OK",
      "Warning"
    ) | Out-Null
    Set-Status "Stop hook 不一致：可点击 [保存并写入 Stop hook] 追加/更新。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "检查失败", "OK", "Error") | Out-Null
  }
}

function Copy-ClaudeStopHookSnippet {
  try {
    $notifyPs1Path = Resolve-AiChatNotifyPs1Path
    if ([string]::IsNullOrWhiteSpace($notifyPs1Path) -or -not (Test-Path -LiteralPath $notifyPs1Path)) {
      [System.Windows.MessageBox]::Show("找不到 ai-chat-notify.ps1。请先安装或在仓库根目录运行配置器。", "错误", "OK", "Error") | Out-Null
      return
    }

    $configPathToUse = if ($controls.ConfigPathBox) { $controls.ConfigPathBox.Text } else { $null }
    $logPathToUse = Get-NotifyLogPathFromUI
    $command = Build-ClaudeStopHookCommand -NotifyPs1Path $notifyPs1Path -ConfigPathToUse $configPathToUse -LogPathToUse $logPathToUse
    $snippet = Build-ClaudeStopHookSnippet -Command $command

    Set-Clipboard -Value $snippet
    Set-Status "已复制 Stop hook 片段到剪贴板。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "复制失败", "OK", "Error") | Out-Null
  }
}

function Restore-ClaudeLatestBackup {
  $settingsPath = Get-ClaudeSettingsPathFromUI
  if ([string]::IsNullOrWhiteSpace($settingsPath)) {
    [System.Windows.MessageBox]::Show("无法确定 Claude Code 配置文件路径。", "错误", "OK", "Error") | Out-Null
    return
  }
  if (-not (Test-Path -LiteralPath $settingsPath)) {
    [System.Windows.MessageBox]::Show("找不到文件：$settingsPath", "错误", "OK", "Error") | Out-Null
    return
  }

  $pattern = $settingsPath + ".bak-*"
  $candidates = @(Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  if (-not $candidates -or $candidates.Count -eq 0) {
    [System.Windows.MessageBox]::Show("未找到备份文件：$pattern", "提示", "OK", "Information") | Out-Null
    Set-Status "未找到备份：$pattern"
    return
  }

  $latest = $candidates[0].FullName
  $impact = $settingsPath
  $risk = "将用备份覆盖当前设置文件：$settingsPath。备份文件：$latest"
  if (-not (Confirm-Dangerous -Operation "恢复 Claude Code 配置备份" -Impact $impact -Risk $risk)) { return }

  try {
    $preRestoreBackup = Backup-File $settingsPath
    Copy-Item -LiteralPath $latest -Destination $settingsPath -Force -ErrorAction Stop

    $validation = Test-JsonTextValid -Path $settingsPath
    if (-not [bool]$validation.ok) {
      if (-not [string]::IsNullOrWhiteSpace($preRestoreBackup) -and (Test-Path -LiteralPath $preRestoreBackup)) {
        Copy-Item -LiteralPath $preRestoreBackup -Destination $settingsPath -Force -ErrorAction Stop
      }
      $detail = if (-not [string]::IsNullOrWhiteSpace($validation.error)) { "`r`n`r`n$($validation.error)" } else { "" }
      [System.Windows.MessageBox]::Show(
        "恢复后检测到设置文件（$settingsPath）无法被解析，已自动回滚到恢复前的备份。`r`n`r`n使用的校验工具：$($validation.tool)$detail",
        "恢复失败（已回滚）",
        "OK",
        "Error"
      ) | Out-Null
      if (-not [string]::IsNullOrWhiteSpace($preRestoreBackup)) {
        Set-Status "恢复失败：已回滚到恢复前备份：$preRestoreBackup"
      } else {
        Set-Status "恢复失败：无恢复前备份可回滚"
      }
      return
    }

    Set-Status "已恢复备份：$latest（重启 Claude Code 生效）。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "恢复失败", "OK", "Error") | Out-Null
  }
}

function Write-ClaudeStopHook {
  $settingsPath = Get-ClaudeSettingsPathFromUI
  if ([string]::IsNullOrWhiteSpace($settingsPath)) {
    [System.Windows.MessageBox]::Show("无法确定 Claude Code 配置文件路径。", "错误", "OK", "Error") | Out-Null
    return $false
  }

  $notifyPs1Path = Resolve-AiChatNotifyPs1Path
  if ([string]::IsNullOrWhiteSpace($notifyPs1Path) -or -not (Test-Path -LiteralPath $notifyPs1Path)) {
    [System.Windows.MessageBox]::Show("找不到 ai-chat-notify.ps1。请先安装或在仓库根目录运行配置器。", "错误", "OK", "Error") | Out-Null
    return $false
  }

  $configPathToUse = if ($controls.ConfigPathBox) { $controls.ConfigPathBox.Text } else { $null }
  $logPathToUse = Get-NotifyLogPathFromUI
  $command = Build-ClaudeStopHookCommand -NotifyPs1Path $notifyPs1Path -ConfigPathToUse $configPathToUse -LogPathToUse $logPathToUse

  $risk = "可能影响 Claude Code 的 hooks 行为；将创建备份并写入 hooks.Stop（并自动迁移旧版 Stop）。"
  if (-not (Confirm-Dangerous -Operation "修改 Claude Code 配置（写入 Stop hook）" -Impact $settingsPath -Risk $risk)) {
    Set-Status "已取消写入 Stop hook。"
    return $false
  }

  try {
    $backup = $null
    $originalText = ""

    if (Test-Path -LiteralPath $settingsPath) {
      $backup = Backup-File $settingsPath
      $originalText = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
    } else {
      Ensure-Directory $settingsPath
    }

    $settings = $null
    if (-not [string]::IsNullOrWhiteSpace($originalText)) {
      $settings = $originalText | ConvertFrom-Json -ErrorAction Stop
    } else {
      $settings = [pscustomobject]@{}
    }

    $hooksObj = $null
    try {
      $p = $settings.PSObject.Properties["hooks"]
      if ($null -ne $p) { $hooksObj = $p.Value }
    } catch {}
    if ($null -ne $hooksObj -and -not ($hooksObj -is [System.Management.Automation.PSCustomObject] -or $hooksObj -is [hashtable])) {
      [System.Windows.MessageBox]::Show(
        "检测到设置文件（$settingsPath）的 hooks 字段不是对象，无法安全写入。请手动修复 hooks 字段后重试（或移除该字段）。",
        "写入失败",
        "OK",
        "Error"
      ) | Out-Null
      return $false
    }
    if ($null -eq $hooksObj) {
      $hooksObj = [pscustomobject]@{}
      $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue $hooksObj -Force
    }

    $stopValue = $null
    $stopIsArray = $false
    try {
      $p = $hooksObj.PSObject.Properties["Stop"]
      if ($null -ne $p) { $stopValue = $p.Value }
      if ($null -ne $stopValue) { $stopIsArray = ($stopValue -is [System.Array]) }
    } catch {}

    $expectedNorm = Normalize-CommandForCompare $command

    $legacyStopValue = $null
    try {
      $p = $settings.PSObject.Properties["Stop"]
      if ($null -ne $p) { $legacyStopValue = $p.Value }
    } catch {}

    $newRule = [pscustomobject]@{
      matcher = "*"
      hooks   = @(
        [pscustomobject]@{
          type    = "command"
          command = $command
        }
      )
    }

    # 规范化为数组：hooks.Stop 必须是 JSON 数组（"hooks": { "Stop": [ ... ] }）。
    $stopRules = @()
    if ($null -ne $stopValue) { $stopRules = @($stopValue) }
    $stopRules = @($stopRules | Where-Object { $null -ne $_ })

    # 迁移旧版顶层 Stop -> hooks.Stop（Claude Code 只识别 hooks 字段）。
    $legacyRules = Ensure-ArrayValue $legacyStopValue
    $legacyRules = @($legacyRules | Where-Object { $null -ne $_ })
    if ($legacyRules.Count -gt 0) {
      $seen = @{}
      foreach ($r in $stopRules) {
        $k = Get-ClaudeStopHookRuleKey -Rule $r
        if (-not [string]::IsNullOrWhiteSpace($k)) { $seen[$k] = $true }
      }
      foreach ($r in $legacyRules) {
        $k = Get-ClaudeStopHookRuleKey -Rule $r
        if ([string]::IsNullOrWhiteSpace($k) -or -not $seen.ContainsKey($k)) {
          $stopRules += $r
          if (-not [string]::IsNullOrWhiteSpace($k)) { $seen[$k] = $true }
        }
      }
      try { $settings.PSObject.Properties.Remove("Stop") } catch {}
    }

    $existingCommands = @(Get-ClaudeStopHookCommandsFromRulesValue -RulesValue $stopRules)
    $hasExpected = $false
    foreach ($cmd in $existingCommands) {
      if ((Normalize-CommandForCompare $cmd) -eq $expectedNorm) { $hasExpected = $true; break }
    }

    # 命令已存在且 hooks.Stop 已是数组，且无需迁移旧版 Stop 时，避免不必要的写回。
    if ($hasExpected -and $stopIsArray -and $legacyRules.Count -eq 0) {
      Set-Status "Stop hook 已存在且匹配（hooks.Stop）：$settingsPath"
      return $true
    }

    if (-not $hasExpected) { $stopRules += $newRule }
    $hooksObj | Add-Member -NotePropertyName "Stop" -NotePropertyValue $stopRules -Force

    $updatedText = $settings | ConvertTo-Json -Depth 10
    Write-Utf8NoBomTextFile -Path $settingsPath -Text $updatedText

    $validation = Test-JsonTextValid -Path $settingsPath
    if (-not [bool]$validation.ok) {
      if (-not [string]::IsNullOrWhiteSpace($backup) -and (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $backup -Destination $settingsPath -Force -ErrorAction Stop
      }
      $detail = if (-not [string]::IsNullOrWhiteSpace($validation.error)) { "`r`n`r`n$($validation.error)" } else { "" }
      [System.Windows.MessageBox]::Show(
        "写入后检测到设置文件（$settingsPath）无法被解析，已自动回滚到备份文件。`r`n`r`n使用的校验工具：$($validation.tool)$detail",
        "写入失败（已回滚）",
        "OK",
        "Error"
      ) | Out-Null
      if (-not [string]::IsNullOrWhiteSpace($backup)) {
        Set-Status "写入失败：JSON 校验未通过，已回滚备份：$backup"
      } else {
        Set-Status "写入失败：JSON 校验未通过（无备份可回滚）"
      }
      return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($backup)) {
      Set-Status "已写入 Stop hook（hooks.Stop，已备份：$backup）。重启 Claude Code 生效。"
    } else {
      Set-Status "已写入 Stop hook（hooks.Stop）。重启 Claude Code 生效。"
    }
    return $true
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "写入失败", "OK", "Error") | Out-Null
    return $false
  }
}

function Save-AndWriteClaudeStopHook {
  if (-not (Save-ConfigFromUI)) { return }
  $ok = Write-ClaudeStopHook
  if ($ok) { Check-ClaudeStopHook }
}

function Apply-ConfigToUI {
  $controls.ConfigPathBox.Text = Normalize-WindowsPath $ConfigPath
  if ($controls.CodexConfigPathBox) {
    $defaultCodexPath = Get-DefaultCodexConfigPath
    if ([string]::IsNullOrWhiteSpace($controls.CodexConfigPathBox.Text) -and -not [string]::IsNullOrWhiteSpace($defaultCodexPath)) {
      $controls.CodexConfigPathBox.Text = Normalize-WindowsPath $defaultCodexPath
    }
  }
  if ($controls.ClaudeSettingsPathBox) {
    if ([string]::IsNullOrWhiteSpace($controls.ClaudeSettingsPathBox.Text)) {
      Sync-ClaudeSettingsPathFromScope
    }
  }

  $providers = @("codex", "claudecode")
  $controls.ProviderBox.ItemsSource = $providers
  $controls.MethodBox.ItemsSource = @("popup", "balloon")

  # Determine config version
  $configVersion = if ($null -ne $config.version) { [int]$config.version } else { 1 }

  $d = $config.defaults
  $providerRaw = if ($null -ne $d.provider) { $d.provider.ToString() } else { "codex" }
  $provider = $providerRaw.Trim().ToLowerInvariant()
  if ($provider -eq "claude-code" -or $provider -eq "claude_code" -or $provider -eq "claude") { $provider = "claudecode" }
  if (-not $providers.Contains($provider)) { $provider = "codex" }
  $controls.ProviderBox.SelectedItem = $provider

  # For version 2, use provider-specific config if available
  if ($configVersion -ge 2 -and $null -ne $config.providers) {
    $providerConfig = $config.providers.$provider
    if ($null -ne $providerConfig) {
      $d = $providerConfig
      $p = if ($null -ne $providerConfig.popup) { $providerConfig.popup } else { $config.popup }
    } else {
      $p = $config.popup
    }
  } else {
    $p = $config.popup
  }

  $method = if ($null -ne $d.method) { $d.method.ToString() } else { "popup" }
  $controls.MethodBox.SelectedItem = $method

  $controls.DurationBox.Text = (TryParse-Int ($d.durationSeconds) 2).ToString()
  $controls.NoSoundBox.IsChecked = [bool]$d.noSound
  $controls.TitleBox.Text = if ($null -ne $d.title) { $d.title.ToString() } else { "" }
  $controls.SubtitleBox.Text = if ($null -ne $d.subtitle) { $d.subtitle.ToString() } else { "" }
  $controls.MessageBox.Text = if ($null -ne $d.message) { $d.message.ToString() } else { "" }

  $controls.PopupWidthBox.Text = (TryParse-Int ($p.width) 360).ToString()
  $controls.PopupMinHeightBox.Text = (TryParse-Int ($p.minHeight) 200).ToString()
  $controls.FontFamilyBox.Text = if ($null -ne $p.fontFamily) { $p.fontFamily.ToString() } else { "Microsoft YaHei UI" }
  $controls.TitleFontSizeBox.Text = (TryParse-Double ($p.titleFontSize) 20).ToString()
  $controls.SubtitleFontSizeBox.Text = (TryParse-Double ($p.subtitleFontSize) 18).ToString()
  $controls.MessageFontSizeBox.Text = (TryParse-Double ($p.messageFontSize) 14).ToString()
  $controls.OkTextBox.Text = if ($null -ne $p.okText) { $p.okText.ToString() } else { "确定" }

  $controls.TitleColorBox.Text = if ($null -ne $p.titleColor) { $p.titleColor.ToString() } else { "#111827" }
  $controls.SubtitleColorBox.Text = if ($null -ne $p.subtitleColor) { $p.subtitleColor.ToString() } else { "#111827" }
  $controls.MessageColorBox.Text = if ($null -ne $p.messageColor) { $p.messageColor.ToString() } else { "#374151" }
  $controls.BackgroundColorBox.Text = if ($null -ne $p.backgroundColor) { $p.backgroundColor.ToString() } else { "#FFFFFF" }
  $controls.BorderColorBox.Text = if ($null -ne $p.borderColor) { $p.borderColor.ToString() } else { "#E6E8EB" }
  $controls.DividerColorBox.Text = if ($null -ne $p.dividerColor) { $p.dividerColor.ToString() } else { "#EEF0F2" }
  $controls.AccentColorBox.Text = if ($null -ne $p.accentColor) { $p.accentColor.ToString() } else { "#2B71D8" }
  $controls.IconTextBox.Text = if ($null -ne $p.iconText) { $p.iconText.ToString() } else { "i" }
  $controls.IconTextColorBox.Text = if ($null -ne $p.iconTextColor) { $p.iconTextColor.ToString() } else { "#FFFFFF" }
  $controls.IconBgColorBox.Text = if ($null -ne $p.iconBackgroundColor) { $p.iconBackgroundColor.ToString() } else { "#2B71D8" }

  if ($controls.EnableCodexLogBox -and $controls.CodexLogPathBox) {
    $g = $config.debug
    $enableLog = $false
    try {
      if ($null -ne $g -and $null -ne $g.enableLog) { $enableLog = [bool]$g.enableLog }
    } catch {}
    $controls.EnableCodexLogBox.IsChecked = $enableLog

    $logPath = $null
    try {
      if ($null -ne $g -and -not [string]::IsNullOrWhiteSpace($g.logPath)) { $logPath = $g.logPath.ToString() }
    } catch {}
    if ([string]::IsNullOrWhiteSpace($logPath)) { $logPath = Get-DefaultNotifyLogPath }
    if (-not [string]::IsNullOrWhiteSpace($logPath)) { $logPath = Normalize-WindowsPath $logPath }
    $controls.CodexLogPathBox.Text = $logPath
  }
}

function Read-UIToConfig {
  # Store reference to current config for preserving other provider settings
  $currentConfig = $script:CurrentConfig

  $provider = $controls.ProviderBox.SelectedItem

  # Provider-specific configuration
  $providerConfig = [ordered]@{
    title           = $controls.TitleBox.Text
    subtitle        = $controls.SubtitleBox.Text
    message         = $controls.MessageBox.Text
    method          = $controls.MethodBox.SelectedItem
    durationSeconds = [int](TryParse-Int $controls.DurationBox.Text 2)
    noSound         = [bool]$controls.NoSoundBox.IsChecked
    popup           = [ordered]@{
      width               = [int](TryParse-Int $controls.PopupWidthBox.Text 360)
      minHeight           = [int](TryParse-Int $controls.PopupMinHeightBox.Text 200)
      fontFamily          = $controls.FontFamilyBox.Text
      titleFontSize       = [double](TryParse-Double $controls.TitleFontSizeBox.Text 20)
      subtitleFontSize    = [double](TryParse-Double $controls.SubtitleFontSizeBox.Text 18)
      messageFontSize     = [double](TryParse-Double $controls.MessageFontSizeBox.Text 14)
      titleColor          = Normalize-HexColor $controls.TitleColorBox.Text
      subtitleColor       = Normalize-HexColor $controls.SubtitleColorBox.Text
      messageColor        = Normalize-HexColor $controls.MessageColorBox.Text
      backgroundColor     = Normalize-HexColor $controls.BackgroundColorBox.Text
      borderColor         = Normalize-HexColor $controls.BorderColorBox.Text
      dividerColor        = Normalize-HexColor $controls.DividerColorBox.Text
      accentColor         = Normalize-HexColor $controls.AccentColorBox.Text
      iconText            = $controls.IconTextBox.Text
      iconTextColor       = Normalize-HexColor $controls.IconTextColorBox.Text
      iconBackgroundColor = Normalize-HexColor $controls.IconBgColorBox.Text
      okText              = $controls.OkTextBox.Text
    }
  }

  # Preserve other provider configurations if they exist
  $providers = [ordered]@{}
  if ($null -ne $currentConfig -and $null -ne $currentConfig.providers) {
    # Iterate over all provider names
    $providerNames = @()
    if ($currentConfig.providers -is [System.Management.Automation.PSCustomObject]) {
      $providerNames = $currentConfig.providers.PSObject.Properties.Name
    } elseif ($currentConfig.providers -is [hashtable] -or $currentConfig.providers -is [System.Collections.Specialized.OrderedDictionary]) {
      $providerNames = $currentConfig.providers.Keys
    }

    foreach ($key in $providerNames) {
      if ($key -ne $provider) {
        # Deep copy the provider config to avoid reference issues
        $providerData = $currentConfig.providers.$key
        $providers[$key] = $providerData
      }
    }
  }
  $providers[$provider] = $providerConfig

  # Default configuration (global fallback)
  $defaults = [ordered]@{
    provider        = $provider
    title           = "AI Chat"
    subtitle        = "任务已完成"
    message         = "请到 CLI/IDE 中查看详细信息"
    method          = "popup"
    durationSeconds = 2
    noSound         = $true
  }

  # Global popup config (fallback for providers without specific popup)
  $popup = [ordered]@{
    width               = [int](TryParse-Int $controls.PopupWidthBox.Text 360)
    minHeight           = [int](TryParse-Int $controls.PopupMinHeightBox.Text 200)
    fontFamily          = $controls.FontFamilyBox.Text
    titleFontSize       = [double](TryParse-Double $controls.TitleFontSizeBox.Text 20)
    subtitleFontSize    = [double](TryParse-Double $controls.SubtitleFontSizeBox.Text 18)
    messageFontSize     = [double](TryParse-Double $controls.MessageFontSizeBox.Text 14)
    titleColor          = Normalize-HexColor $controls.TitleColorBox.Text
    subtitleColor       = Normalize-HexColor $controls.SubtitleColorBox.Text
    messageColor        = Normalize-HexColor $controls.MessageColorBox.Text
    backgroundColor     = Normalize-HexColor $controls.BackgroundColorBox.Text
    borderColor         = Normalize-HexColor $controls.BorderColorBox.Text
    dividerColor        = Normalize-HexColor $controls.DividerColorBox.Text
    accentColor         = Normalize-HexColor $controls.AccentColorBox.Text
    iconText            = $controls.IconTextBox.Text
    iconTextColor       = Normalize-HexColor $controls.IconTextColorBox.Text
    iconBackgroundColor = Normalize-HexColor $controls.IconBgColorBox.Text
    okText              = $controls.OkTextBox.Text
  }

  $debug = [ordered]@{
    enableLog = if ($controls.EnableCodexLogBox) { [bool]$controls.EnableCodexLogBox.IsChecked } else { $false }
    logPath   = if ($controls.CodexLogPathBox) { $controls.CodexLogPathBox.Text } else { "" }
  }

  return [ordered]@{
    version  = 2
    defaults = $defaults
    providers = $providers
    popup    = $popup
    debug    = $debug
  }
}

function Generate-Snippet {
  $useInstalled = [bool]$controls.CmdInstalledRadio.IsChecked

  $ps1Path = $null
  if ($useInstalled) {
    $ps1Path = Resolve-AiChatNotifyPs1Path
  } else {
    $ps1Path = Join-Path (Join-Path $repoRoot "scripts") "ai-chat-notify.ps1"
  }
  $ps1 = Convert-ToForwardSlashPath (Normalize-WindowsPath $ps1Path)

  $cfgPath = if ($controls.ConfigPathBox) { $controls.ConfigPathBox.Text } else { $null }
  $cfg = Convert-ToForwardSlashPath (Normalize-WindowsPath $cfgPath)

  $logPath = Get-NotifyLogPathFromUI
  $log = Convert-ToForwardSlashPath (Normalize-WindowsPath $logPath)

  $method = $controls.MethodBox.SelectedItem
  $duration = (TryParse-Int $controls.DurationBox.Text 2)
  $noSound = [bool]$controls.NoSoundBox.IsChecked

  $args = New-Object System.Collections.Generic.List[string]
  $args.Add("-NoProfile")
  $args.Add("-ExecutionPolicy")
  $args.Add("Bypass")
  $args.Add("-File")
  $args.Add("`"$ps1`"")
  if (-not [string]::IsNullOrWhiteSpace($cfg)) {
    $args.Add("-ConfigPath")
    $args.Add("`"$cfg`"")
  }
  if (-not [string]::IsNullOrWhiteSpace($log)) {
    $args.Add("-LogPath")
    $args.Add("`"$log`"")
  }
  if (-not [string]::IsNullOrWhiteSpace($method)) {
    $args.Add("-Method")
    $args.Add("`"$method`"")
  }
  $args.Add("-DurationSeconds")
  $args.Add($duration.ToString())
  if ($noSound) { $args.Add("-NoSound") }

  $common = ($args -join " ")
  $eventFileLine = '$eventFile = "C:/path/to/event.json"'

  if ([bool]$controls.InputStdinRadio.IsChecked) {
    return @(
      "# AI 工具集成：工具会把事件 JSON 作为最后一个参数追加"
      "powershell.exe $common -EventJson"
    ) -join "`r`n"
  }

  if ([bool]$controls.InputEventFileRadio.IsChecked) {
    return @(
      $eventFileLine
      "powershell.exe $common -EventFile `"$eventFile`""
    ) -join "`r`n"
  }

  return @(
    $eventFileLine
    "powershell.exe $common -EventJson (Get-Content `"$eventFile`" -Raw)"
  ) -join "`r`n"
}

function Refresh-Snippet {
  $controls.SnippetBox.Text = Generate-Snippet
}

function Invoke-Notify {
  param([Parameter(Mandatory = $true)][ValidateSet("popup", "balloon")][string]$MethodToTest)

  $candidates = @(
    (Join-Path (Join-Path $repoRoot "scripts") "ai-chat-notify.ps1"),
    (Join-Path $repoRoot "ai-chat-notify.ps1")
  )

  $mainScript = $null
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      $mainScript = $candidate
      break
    }
  }

  if ([string]::IsNullOrWhiteSpace($mainScript)) {
    [System.Windows.MessageBox]::Show(
      ("找不到入口脚本。已尝试：`r`n" + ($candidates -join "`r`n")),
      "错误",
      "OK",
      "Error"
    ) | Out-Null
    return
  }

  try {
    $tempDir = [System.IO.Path]::GetTempPath()
    if ([string]::IsNullOrWhiteSpace($tempDir)) { $tempDir = $env:TEMP }
    if ([string]::IsNullOrWhiteSpace($tempDir)) { $tempDir = $repoRoot }

    $previewConfigPath = Join-Path $tempDir "ai-chat-notify-preview-config.json"
    $previewConfig = Read-UIToConfig
    Save-JsonFile $previewConfig $previewConfigPath

    $duration = [int](TryParse-Int $controls.DurationBox.Text 2)
    $noSound = [bool]$controls.NoSoundBox.IsChecked

    $invokeParams = @{
      ConfigPath      = $previewConfigPath
      Method          = $MethodToTest
      Title           = $controls.TitleBox.Text
      Subtitle        = $controls.SubtitleBox.Text
      Message         = $controls.MessageBox.Text
      DurationSeconds = $duration
    }
    if ($noSound) { $invokeParams.NoSound = $true }

    $null = & $mainScript @invokeParams
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "错误", "OK", "Error") | Out-Null
  }
}

function Reload-Config {
  $pathValue = $controls.ConfigPathBox.Text
  $loaded = Load-JsonFile $pathValue
  if ($null -eq $loaded) {
    $config = New-DefaultConfig
    Set-Status "未找到或无法读取配置文件，已载入默认配置。"
  } else {
    $config = $loaded
    if ($null -eq $config.defaults) { $config | Add-Member -NotePropertyName defaults -NotePropertyValue @{} -Force }
    if ($null -eq $config.popup) { $config | Add-Member -NotePropertyName popup -NotePropertyValue @{} -Force }
    Set-Status "已重新加载配置。"
  }
  Apply-ConfigToUI
  Refresh-Snippet
}

function Write-Utf8NoBomTextFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Text
  )

  Ensure-Directory $Path
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Backup-File {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $ts = Get-Date -Format "yyyyMMdd-HHmmss"
  $backupPath = $Path + ".bak-" + $ts
  Copy-Item -LiteralPath $Path -Destination $backupPath -Force -ErrorAction Stop
  return $backupPath
}

function Test-TomlTextValid {
  param([Parameter(Mandatory = $true)][string]$Path)

  $python = Get-Command "python" -ErrorAction SilentlyContinue
  if ($python) {
    $out = & $python.Source -c "import sys, pathlib, tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))" $Path 2>&1 | Out-String
    return [ordered]@{
      ok    = ($LASTEXITCODE -eq 0)
      tool  = "python-tomllib"
      error = $out.Trim()
    }
  }

  $codex = Get-Command "codex" -ErrorAction SilentlyContinue
  $defaultPath = Get-DefaultCodexConfigPath
  $canUseCodex = $codex -and -not [string]::IsNullOrWhiteSpace($defaultPath) -and
    ((Normalize-WindowsPath $defaultPath).ToLowerInvariant() -eq (Normalize-WindowsPath $Path).ToLowerInvariant())
  if ($canUseCodex) {
    $out = & $codex.Source --version 2>&1 | Out-String
    return [ordered]@{
      ok    = ($LASTEXITCODE -eq 0)
      tool  = "codex --version"
      error = $out.Trim()
    }
  }

  return [ordered]@{
    ok    = $true
    tool  = "skip"
    error = ""
  }
}

function Write-CodexNotify {
  $tomlPath = Get-CodexTomlPathFromUI
  if ([string]::IsNullOrWhiteSpace($tomlPath)) {
    [System.Windows.MessageBox]::Show("无法确定 Codex 配置文件路径（config.toml）。", "错误", "OK", "Error") | Out-Null
    return $false
  }

  $notifyPs1Path = Resolve-AiChatNotifyPs1Path
  if ([string]::IsNullOrWhiteSpace($notifyPs1Path) -or -not (Test-Path -LiteralPath $notifyPs1Path)) {
    $candidates = @(
      (Resolve-AiChatNotifyPs1Path),
      (Join-Path (Join-Path $repoRoot "scripts") "ai-chat-notify.ps1")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    [System.Windows.MessageBox]::Show(
      ("找不到 ai-chat-notify.ps1。请先安装或在仓库根目录运行配置器。`r`n已尝试：`r`n" + ($candidates -join "`r`n")),
      "错误",
      "OK",
      "Error"
    ) | Out-Null
    return $false
  }

  $configPathToUse = if ($controls.ConfigPathBox) { $controls.ConfigPathBox.Text } else { $null }
  $logPathToUse = Get-NotifyLogPathFromUI
  $notifyLine = Build-CodexNotifyLine -NotifyPs1Path $notifyPs1Path -ConfigPathToUse $configPathToUse -LogPathToUse $logPathToUse

  $risk = "可能影响 Codex 的通知触发行为；将创建备份并覆盖 notify 设置。"
  if (-not (Confirm-Dangerous -Operation "修改 Codex 配置（写入 notify）" -Impact $tomlPath -Risk $risk)) {
    Set-Status "已取消写入 notify。"
    return $false
  }

  try {
    $backup = $null
    if (Test-Path -LiteralPath $tomlPath) {
      $backup = Backup-File $tomlPath
    } else {
      Ensure-Directory $tomlPath
    }

    $original = if (Test-Path -LiteralPath $tomlPath) {
      Get-Content -LiteralPath $tomlPath -Raw -Encoding UTF8 -ErrorAction Stop
    } else {
      ""
    }

    $updated = Upsert-NotifyInTomlText -TomlText $original -NotifyLine $notifyLine
    Write-Utf8NoBomTextFile -Path $tomlPath -Text $updated

    $validation = Test-TomlTextValid -Path $tomlPath
    if (-not [bool]$validation.ok) {
      if (-not [string]::IsNullOrWhiteSpace($backup) -and (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $backup -Destination $tomlPath -Force -ErrorAction Stop
      }
      $detail = if (-not [string]::IsNullOrWhiteSpace($validation.error)) { "`r`n`r`n$($validation.error)" } else { "" }
      [System.Windows.MessageBox]::Show(
        "写入后检测到 config.toml 无法被解析，已自动回滚到备份文件。`r`n`r`n使用的校验工具：$($validation.tool)$detail",
        "写入失败（已回滚）",
        "OK",
        "Error"
      ) | Out-Null
      if (-not [string]::IsNullOrWhiteSpace($backup)) {
        Set-Status "写入失败：TOML 校验未通过，已回滚备份：$backup"
      } else {
        Set-Status "写入失败：TOML 校验未通过（无备份可回滚）"
      }
      return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($backup)) {
      Set-Status "已写入 notify（已备份：$backup）。重启 Codex 生效。"
    } else {
      Set-Status "已写入 notify。重启 Codex 生效。"
    }
    return $true
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "写入失败", "OK", "Error") | Out-Null
    return $false
  }
}

Apply-ConfigToUI
Refresh-Snippet

$controls.RefreshSnippetBtn.Add_Click({ Refresh-Snippet })
$controls.CopySnippetBtn.Add_Click({
  Refresh-Snippet
  try {
    Set-Clipboard -Value $controls.SnippetBox.Text
    Set-Status "已复制集成片段到剪贴板。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "复制失败", "OK", "Error") | Out-Null
  }
})

$controls.SaveBtn.Add_Click({ [void](Save-ConfigFromUI) })

$controls.CloseBtn.Add_Click({ $window.Close() })

$controls.TestPopupBtn.Add_Click({ Invoke-Notify -MethodToTest "popup" })
$controls.TestBalloonBtn.Add_Click({ Invoke-Notify -MethodToTest "balloon" })

$controls.ReloadBtn.Add_Click({ Reload-Config })

$controls.OpenConfigDirBtn.Add_Click({
  try {
    $pathValue = $controls.ConfigPathBox.Text
    $dir = Split-Path -Parent $pathValue
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Start-Process -FilePath "explorer.exe" -ArgumentList @($dir) | Out-Null
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "打开失败", "OK", "Error") | Out-Null
  }
})

if ($controls.GoCodexTabBtn) {
  $controls.GoCodexTabBtn.Add_Click({
    try {
      if ($controls.MainTabs -and $controls.InstallTabItem) {
        $controls.MainTabs.SelectedItem = $controls.InstallTabItem
        Set-Status "请在此页点击 [保存并写入 notify]，然后重启 Codex 生效。"
      }
    } catch {
      [System.Windows.MessageBox]::Show($_.Exception.Message, "跳转失败", "OK", "Error") | Out-Null
    }
  })
}

if ($controls.GoClaudeTabBtn) {
  $controls.GoClaudeTabBtn.Add_Click({
    try {
      if ($controls.MainTabs -and $controls.InstallTabItem) {
        $controls.MainTabs.SelectedItem = $controls.InstallTabItem
        Set-Status "请在此页点击 [保存并写入 Stop hook]，然后重启 Claude Code 生效。"
      }
    } catch {
      [System.Windows.MessageBox]::Show($_.Exception.Message, "跳转失败", "OK", "Error") | Out-Null
    }
  })
}

$controls.InstallBtn.Add_Click({
  $installScript = Join-Path $repoRoot "install.ps1"
  if (-not (Test-Path -LiteralPath $installScript)) {
    [System.Windows.MessageBox]::Show("找不到：$installScript", "错误", "OK", "Error") | Out-Null
    return
  }

  $installDir = Get-DefaultInstallDir
  $impact = "用户级 PATH；安装目录：$installDir（会覆盖同名文件）"
  $risk = "可能影响你的 PATH；覆盖安装目录下的脚本文件；需要重启终端生效。"
  if (-not (Confirm-Dangerous -Operation "安装/更新到 PATH" -Impact $impact -Risk $risk)) { return }

  try {
    & $installScript -AddToPath -Force
    Set-Status "已执行安装（PATH 可能需要重启终端生效）。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "安装失败", "OK", "Error") | Out-Null
  }
})

$controls.UninstallBtn.Add_Click({
  $uninstallScript = Join-Path $repoRoot "uninstall.ps1"
  if (-not (Test-Path -LiteralPath $uninstallScript)) {
    [System.Windows.MessageBox]::Show("找不到：$uninstallScript", "错误", "OK", "Error") | Out-Null
    return
  }

  $installDir = Get-DefaultInstallDir
  $impact = "用户级 PATH；安装目录：$installDir（会删除该目录下的脚本文件）"
  $risk = "可能影响你的 PATH；删除安装目录下的脚本文件；需要重启终端生效。"
  if (-not (Confirm-Dangerous -Operation "卸载并移除 PATH" -Impact $impact -Risk $risk)) { return }

  try {
    & $uninstallScript -RemoveFromPath
    Set-Status "已执行卸载（PATH 可能需要重启终端生效）。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "卸载失败", "OK", "Error") | Out-Null
  }
})

if ($controls.BrowseCodexConfigBtn) {
  $controls.BrowseCodexConfigBtn.Add_Click({
    try {
      $dlg = New-Object Microsoft.Win32.OpenFileDialog
      $dlg.Title = "选择 Codex 配置文件（config.toml）"
      $dlg.Filter = "TOML (*.toml)|*.toml|All files (*.*)|*.*"
      $dlg.FileName = "config.toml"

      $defaultPath = Get-DefaultCodexConfigPath
      if (-not [string]::IsNullOrWhiteSpace($defaultPath)) {
        $dir = Split-Path -Parent $defaultPath
        if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
          $dlg.InitialDirectory = $dir
        }
      }

      $result = $dlg.ShowDialog()
      if ($result -eq $true -and $controls.CodexConfigPathBox) {
        $controls.CodexConfigPathBox.Text = $dlg.FileName
      }
    } catch {
      [System.Windows.MessageBox]::Show($_.Exception.Message, "选择失败", "OK", "Error") | Out-Null
    }
  })
}

if ($controls.OpenCodexConfigBtn) {
  $controls.OpenCodexConfigBtn.Add_Click({ Open-CodexConfig })
}

if ($controls.CheckCodexNotifyBtn) {
  $controls.CheckCodexNotifyBtn.Add_Click({ Check-CodexNotify })
}

if ($controls.EnableCodexLogBox) {
  $controls.EnableCodexLogBox.Add_Checked({ Update-CodexLogUiState })
  $controls.EnableCodexLogBox.Add_Unchecked({ Update-CodexLogUiState })
  Update-CodexLogUiState
}

if ($controls.OpenCodexLogBtn) {
  $controls.OpenCodexLogBtn.Add_Click({ Open-NotifyLog })
}

if ($controls.CopyCodexNotifyBtn) {
  $controls.CopyCodexNotifyBtn.Add_Click({ Copy-CodexNotifyLine })
}

if ($controls.RestoreCodexBackupBtn) {
  $controls.RestoreCodexBackupBtn.Add_Click({ Restore-CodexLatestBackup })
}

if ($controls.WriteCodexNotifyBtn) {
  $controls.WriteCodexNotifyBtn.Add_Click({ Save-AndWriteCodexNotify })
}

if ($controls.ClaudeScopeProjectRadio) {
  $controls.ClaudeScopeProjectRadio.Add_Checked({ Sync-ClaudeSettingsPathFromScope })
}
if ($controls.ClaudeScopeGlobalRadio) {
  $controls.ClaudeScopeGlobalRadio.Add_Checked({ Sync-ClaudeSettingsPathFromScope })
}

if ($controls.BrowseClaudeSettingsBtn) {
  $controls.BrowseClaudeSettingsBtn.Add_Click({
    try {
      $dlg = New-Object Microsoft.Win32.OpenFileDialog
      $dlg.Title = "选择 Claude Code 设置文件"
      $dlg.Filter = "JSON (*.json)|*.json|All files (*.*)|*.*"

      $scope = Get-ClaudeSettingsScopeFromUI
      $defaultPath = Get-DefaultClaudeSettingsPath -Scope $scope
      if (-not [string]::IsNullOrWhiteSpace($defaultPath)) {
        try { $dlg.FileName = (Split-Path -Leaf $defaultPath) } catch {}
        $dir = Split-Path -Parent $defaultPath
        if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
          $dlg.InitialDirectory = $dir
        }
      }

      $result = $dlg.ShowDialog()
      if ($result -eq $true -and $controls.ClaudeSettingsPathBox) {
        $controls.ClaudeSettingsPathBox.Text = $dlg.FileName
      }
    } catch {
      [System.Windows.MessageBox]::Show($_.Exception.Message, "选择失败", "OK", "Error") | Out-Null
    }
  })
}

if ($controls.OpenClaudeSettingsBtn) {
  $controls.OpenClaudeSettingsBtn.Add_Click({ Open-ClaudeSettings })
}

if ($controls.OpenClaudeDebugBtn) {
  $controls.OpenClaudeDebugBtn.Add_Click({ Open-ClaudeDebug })
}

if ($controls.CheckClaudeStopHookBtn) {
  $controls.CheckClaudeStopHookBtn.Add_Click({ Check-ClaudeStopHook })
}

if ($controls.CopyClaudeStopHookBtn) {
  $controls.CopyClaudeStopHookBtn.Add_Click({ Copy-ClaudeStopHookSnippet })
}

if ($controls.RestoreClaudeBackupBtn) {
  $controls.RestoreClaudeBackupBtn.Add_Click({ Restore-ClaudeLatestBackup })
}

if ($controls.WriteClaudeStopHookBtn) {
  $controls.WriteClaudeStopHookBtn.Add_Click({ Save-AndWriteClaudeStopHook })
}

Set-Status "就绪：先测试并保存配置，然后写入 Codex notify / Claude hooks.Stop。"
[void]$window.ShowDialog()
