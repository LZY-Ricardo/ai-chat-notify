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
      return (Join-Path $env:LOCALAPPDATA "ai-chat-notify\\config.json")
    }
  } catch {}
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
      return (Join-Path $env:USERPROFILE ".ai-chat-notify\\config.json")
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
    version  = 1
    defaults = [ordered]@{
      provider        = "codex"
      title           = "Codex"
      subtitle        = "任务已完成"
      message         = "请到 CLI/IDE 中查看详细信息"
      method          = "popup"
      durationSeconds = 2
      noSound         = $true
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

if ($null -eq $config.defaults) { $config | Add-Member -NotePropertyName defaults -NotePropertyValue @{} }
if ($null -eq $config.popup) { $config | Add-Member -NotePropertyName popup -NotePropertyValue @{} }

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

    <TabControl Grid.Row="1" Margin="0,12,0,12">
      <TabItem Header="基础">
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
          </Grid>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="样式（Popup）">
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

      <TabItem Header="集成片段">
        <Grid Margin="12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
          </Grid.RowDefinitions>

          <GroupBox Grid.Row="0" Header="调用位置" Padding="10">
            <StackPanel Orientation="Horizontal">
              <RadioButton x:Name="CmdInstalledRadio" Content="已安装（PATH）" IsChecked="True" Margin="0,0,18,0" />
              <RadioButton x:Name="CmdLocalRadio" Content="本地仓库路径" />
            </StackPanel>
          </GroupBox>

          <GroupBox Grid.Row="1" Header="事件输入方式" Padding="10" Margin="0,10,0,0">
            <StackPanel Orientation="Horizontal">
              <RadioButton x:Name="InputStdinRadio" Content="stdin（推荐）" IsChecked="True" Margin="0,0,18,0" />
              <RadioButton x:Name="InputEventFileRadio" Content="-EventFile" Margin="0,0,18,0" />
              <RadioButton x:Name="InputPositionalRadio" Content="位置参数 JSON" />
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

      <TabItem Header="安装/卸载">
        <Grid Margin="12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
          </Grid.RowDefinitions>

          <TextBlock Grid.Row="0" Text="这里会调用 install.ps1 / uninstall.ps1（会修改用户级 PATH）。" Foreground="#6B7280" />

          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,10,0,0">
            <Button x:Name="InstallBtn" Content="安装到 PATH" Padding="12,8" />
            <Button x:Name="UninstallBtn" Content="从 PATH 卸载" Padding="12,8" Margin="10,0,0,0" />
          </StackPanel>

          <TextBlock Grid.Row="2" Margin="0,12,0,0" TextWrapping="Wrap"
            Text="提示：修改 PATH 需要重启终端生效。安装后可直接使用 ai-chat-notify 命令。" />
        </Grid>
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
    [Parameter(Mandatory = $true)][string]$Impact
  )
  $msg = "⚠️ 危险操作检测！`n操作类型：$Operation`n影响范围：$Impact`n风险评估：可能修改你的用户级系统配置（PATH）。`n`n请确认是否继续？"
  $result = [System.Windows.MessageBox]::Show($msg, "确认", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
  return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Apply-ConfigToUI {
  $controls.ConfigPathBox.Text = $ConfigPath

  $providers = @("auto", "codex", "claude-code", "generic")
  $controls.ProviderBox.ItemsSource = $providers
  $controls.MethodBox.ItemsSource = @("popup", "balloon")

  $d = $config.defaults
  $p = $config.popup

  $provider = if ($null -ne $d.provider) { $d.provider.ToString() } else { "codex" }
  if (-not $providers.Contains($provider)) { $providers += $provider; $controls.ProviderBox.ItemsSource = $providers }
  $controls.ProviderBox.SelectedItem = $provider

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
}

function Read-UIToConfig {
  $defaults = [ordered]@{
    provider        = $controls.ProviderBox.SelectedItem
    title           = $controls.TitleBox.Text
    subtitle        = $controls.SubtitleBox.Text
    message         = $controls.MessageBox.Text
    method          = $controls.MethodBox.SelectedItem
    durationSeconds = [int](TryParse-Int $controls.DurationBox.Text 2)
    noSound         = [bool]$controls.NoSoundBox.IsChecked
  }

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

  return [ordered]@{
    version  = 1
    defaults = $defaults
    popup    = $popup
  }
}

function Generate-Snippet {
  $useInstalled = [bool]$controls.CmdInstalledRadio.IsChecked
  $cmd = if ($useInstalled) { "ai-chat-notify" } else { "& `"$repoRoot\\ai-chat-notify.cmd`"" }

  $method = $controls.MethodBox.SelectedItem
  $duration = (TryParse-Int $controls.DurationBox.Text 2)
  $noSound = [bool]$controls.NoSoundBox.IsChecked
  $commonArgs = @("-Method `"$method`"", "-DurationSeconds $duration")
  if ($noSound) { $commonArgs += "-NoSound" }
  $common = ($commonArgs -join " ")

  $eventFileLine = '$eventFile = "C:\path\to\event.json"'

  if ([bool]$controls.InputStdinRadio.IsChecked) {
    if ($useInstalled) {
      return @(
        $eventFileLine
        "Get-Content `"$eventFile`" -Raw | $cmd $common"
      ) -join "`r`n"
    }
    return @(
      $eventFileLine
      "Get-Content `"$eventFile`" -Raw | $cmd $common"
    ) -join "`r`n"
  }

  if ([bool]$controls.InputEventFileRadio.IsChecked) {
    return @(
      $eventFileLine
      "$cmd -EventFile `"$eventFile`" $common"
    ) -join "`r`n"
  }

  return @(
    $eventFileLine
    "$cmd (Get-Content `"$eventFile`" -Raw) $common"
  ) -join "`r`n"
}

function Refresh-Snippet {
  $controls.SnippetBox.Text = Generate-Snippet
}

function Invoke-Notify {
  param([Parameter(Mandatory = $true)][ValidateSet("popup", "balloon")][string]$MethodToTest)

  $candidates = @(
    (Join-Path $repoRoot "scripts\\ai-chat-notify.ps1"),
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

  $pathValue = $controls.ConfigPathBox.Text
  try {
    $null = & $mainScript -ConfigPath $pathValue -Method $MethodToTest -DurationSeconds 2 -NoSound `
      -Title "预览" -Subtitle "ai-chat-notify" -Message "这是一条预览通知（来自配置器）。"
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

$controls.SaveBtn.Add_Click({
  try {
    $pathValue = $controls.ConfigPathBox.Text
    $cfg = Read-UIToConfig
    Save-JsonFile $cfg $pathValue
    Set-Status "已保存：$pathValue"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "保存失败", "OK", "Error") | Out-Null
  }
})

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

$controls.InstallBtn.Add_Click({
  $installScript = Join-Path $repoRoot "install.ps1"
  if (-not (Test-Path -LiteralPath $installScript)) {
    [System.Windows.MessageBox]::Show("找不到：$installScript", "错误", "OK", "Error") | Out-Null
    return
  }

  if (-not (Confirm-Dangerous -Operation "修改用户 PATH（安装到 PATH）" -Impact "当前用户级 PATH")) { return }

  try {
    & $installScript -AddToPath
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

  if (-not (Confirm-Dangerous -Operation "修改用户 PATH（从 PATH 卸载）" -Impact "当前用户级 PATH")) { return }

  try {
    & $uninstallScript -RemoveFromPath
    Set-Status "已执行卸载（PATH 可能需要重启终端生效）。"
  } catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "卸载失败", "OK", "Error") | Out-Null
  }
})

Set-Status "就绪"
[void]$window.ShowDialog()
