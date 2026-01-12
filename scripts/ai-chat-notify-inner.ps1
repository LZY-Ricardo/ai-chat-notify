$ErrorActionPreference = 'Stop'

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

$configPath = Get-NotifyEnvValue "AI_CHAT_NOTIFY_CONFIG_PATH" @("CODEX_NOTIFY_CONFIG_PATH")
if ([string]::IsNullOrWhiteSpace($configPath)) {
  try {
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
      $configPath = (Join-Path (Join-Path $env:LOCALAPPDATA "ai-chat-notify") "config.json")
    } elseif (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
      $configPath = (Join-Path (Join-Path $env:USERPROFILE ".ai-chat-notify") "config.json")
    }
  } catch {}
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

function Load-NotifyConfig {
  param([AllowNull()][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    return ($raw | ConvertFrom-Json -ErrorAction Stop)
  } catch {
    Log ("config read error: {0}" -f $_.Exception.Message)
    return $null
  }
}

$title = Get-NotifyEnvValue "AI_CHAT_NOTIFY_TITLE" @("CODEX_NOTIFY_TITLE")
$subtitle = Get-NotifyEnvValue "AI_CHAT_NOTIFY_SUBTITLE" @("CODEX_NOTIFY_SUBTITLE")
$message = Get-NotifyEnvValue "AI_CHAT_NOTIFY_MESSAGE" @("CODEX_NOTIFY_MESSAGE")
$method = Get-NotifyEnvValue "AI_CHAT_NOTIFY_METHOD" @("CODEX_NOTIFY_METHOD")
$durationSeconds = Get-NotifyEnvValue "AI_CHAT_NOTIFY_DURATION_SECONDS" @("CODEX_NOTIFY_DURATION_SECONDS")
$noSound = (Get-NotifyEnvValue "AI_CHAT_NOTIFY_NOSOUND" @("CODEX_NOTIFY_NOSOUND")) -eq '1'
$logPath = Get-NotifyEnvValue "AI_CHAT_NOTIFY_LOG" @("CODEX_NOTIFY_LOG")

function Log {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($logPath)) { return }
  try {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    Add-Content -Path $logPath -Encoding UTF8 -Value "[$ts] ai-chat-notify(inner) $Text"
  } catch {}
}

$notifyConfig = Load-NotifyConfig $configPath
$popupConfig = if ($null -eq $notifyConfig) { $null } else { (Get-ObjectProperty $notifyConfig @("popup")) }

function ConvertTo-Color {
  param([AllowNull()][string]$Hex)
  if ([string]::IsNullOrWhiteSpace($Hex)) { return $null }
  $s = $Hex.Trim()
  if ($s.StartsWith("#")) { $s = $s.Substring(1) }
  if ($s.Length -eq 6) { $s = "FF$s" }
  if ($s.Length -ne 8) { return $null }
  try {
    $a = [Convert]::ToByte($s.Substring(0, 2), 16)
    $r = [Convert]::ToByte($s.Substring(2, 2), 16)
    $g = [Convert]::ToByte($s.Substring(4, 2), 16)
    $b = [Convert]::ToByte($s.Substring(6, 2), 16)
    return [System.Windows.Media.Color]::FromArgb($a, $r, $g, $b)
  } catch {
    return $null
  }
}

function New-SolidBrush {
  param([AllowNull()][string]$Hex)
  $c = ConvertTo-Color $Hex
  if ($null -eq $c) { return $null }
  return (New-Object System.Windows.Media.SolidColorBrush -ArgumentList $c)
}

$body = if ([string]::IsNullOrWhiteSpace($subtitle)) { $message } else { "$subtitle`r`n$message" }

try {
  $seconds = 5
  try {
    if (-not [string]::IsNullOrWhiteSpace($durationSeconds)) {
      $seconds = [int]$durationSeconds
    }
  } catch {}
  if ($seconds -lt 0) { $seconds = 0 }
  if ($seconds -gt 120) { $seconds = 120 }

  $isPopup = (-not [string]::IsNullOrWhiteSpace($method) -and $method.ToLowerInvariant() -eq 'popup')
  if (-not $isPopup -and $seconds -lt 1) { $seconds = 5 }

  if ($isPopup) {
    try {
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null

      $xaml = @"
<Window
  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  WindowStartupLocation="CenterScreen"
  Width="360"
  SizeToContent="Height"
  MinHeight="200"
  ResizeMode="NoResize"
  WindowStyle="None"
  AllowsTransparency="True"
  Background="Transparent"
  Topmost="True"
  ShowInTaskbar="False"
  SnapsToDevicePixels="True"
  UseLayoutRounding="True">
  <Border
    x:Name="RootBorder"
    CornerRadius="14"
    BorderThickness="1"
    BorderBrush="#E6E8EB"
    Background="#FFFFFF">
    <Border.Effect>
      <DropShadowEffect BlurRadius="22" ShadowDepth="0" Opacity="0.22" Color="#000000" />
    </Border.Effect>

    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="48" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="72" />
      </Grid.RowDefinitions>

      <Grid Grid.Row="0" Background="Transparent">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="48" />
        </Grid.ColumnDefinitions>

        <TextBlock
          x:Name="TitleText"
          Margin="16,0,0,0"
          VerticalAlignment="Center"
          FontFamily="Microsoft YaHei UI"
          FontSize="20"
          FontWeight="SemiBold"
          Foreground="#111827" />

        <Button
          x:Name="CloseButton"
          Grid.Column="1"
          Width="34"
          Height="34"
          Margin="0,0,12,0"
          VerticalAlignment="Center"
          Background="Transparent"
          BorderThickness="0"
          Cursor="Hand">
          <Button.Template>
            <ControlTemplate TargetType="Button">
              <Border x:Name="Cb" Background="Transparent" CornerRadius="8">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
              </Border>
              <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                  <Setter TargetName="Cb" Property="Background" Value="#F3F4F6" />
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                  <Setter TargetName="Cb" Property="Background" Value="#E5E7EB" />
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Button.Template>
          <TextBlock
            Text="&#x2715;"
            FontFamily="Segoe UI"
            FontSize="16"
            Foreground="#6B7280"
            HorizontalAlignment="Center"
            VerticalAlignment="Center" />
        </Button>
      </Grid>
      <Border x:Name="HeaderDivider" Grid.Row="0" BorderBrush="#EEF0F2" BorderThickness="0,0,0,1" VerticalAlignment="Bottom" />

      <Grid Grid.Row="1" Margin="18,16,18,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="72" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>

        <Grid Grid.Column="0" Width="56" Height="56" HorizontalAlignment="Left" VerticalAlignment="Top">
          <Ellipse x:Name="IconEllipse" Fill="#2B71D8">
            <Ellipse.Effect>
              <DropShadowEffect BlurRadius="12" ShadowDepth="2" Opacity="0.25" Color="#000000" />
            </Ellipse.Effect>
          </Ellipse>
          <TextBlock
            x:Name="IconText"
            Text="i"
            FontFamily="Segoe UI"
            FontSize="36"
            FontWeight="Bold"
            Foreground="#FFFFFF"
            HorizontalAlignment="Center"
            VerticalAlignment="Center"
            Margin="0,-1,0,0" />
        </Grid>

        <StackPanel Grid.Column="1" Margin="10,0,0,0">
          <TextBlock
            x:Name="SubtitleText"
            FontFamily="Microsoft YaHei UI"
            FontSize="18"
            FontWeight="SemiBold"
            Foreground="#111827"
            TextWrapping="Wrap" />

          <TextBlock
            x:Name="MessageText"
            Margin="0,8,0,0"
            FontFamily="Microsoft YaHei UI"
            FontSize="14"
            Foreground="#374151"
            TextWrapping="Wrap" />
        </StackPanel>
      </Grid>

      <Border x:Name="FooterDivider" Grid.Row="2" BorderBrush="#EEF0F2" BorderThickness="0,1,0,0" VerticalAlignment="Top" />
      <Grid Grid.Row="2" Background="Transparent">
        <Button
          x:Name="OkButton"
          Content=""
          Width="140"
          Height="40"
          HorizontalAlignment="Center"
          VerticalAlignment="Center"
          FontFamily="Microsoft YaHei UI"
          FontSize="14"
          FontWeight="SemiBold"
          Foreground="#FFFFFF"
          Background="#2B71D8"
          BorderThickness="0"
          Cursor="Hand"
          Padding="8,0">
          <Button.Template>
            <ControlTemplate TargetType="Button">
              <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10">
                <Border.Effect>
                  <DropShadowEffect BlurRadius="12" ShadowDepth="2" Opacity="0.22" Color="#000000" />
                </Border.Effect>
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
              </Border>
              <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                  <Setter TargetName="Bd" Property="Background" Value="#2462BE" />
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                  <Setter TargetName="Bd" Property="Background" Value="#1D4FA0" />
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                  <Setter TargetName="Bd" Property="Opacity" Value="0.6" />
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Button.Template>
        </Button>
      </Grid>
    </Grid>
  </Border>
</Window>
"@

      $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
      $window = [Windows.Markup.XamlReader]::Load($reader)

      $titleText = $window.FindName("TitleText")
      $subtitleText = $window.FindName("SubtitleText")
      $messageText = $window.FindName("MessageText")
      $closeButton = $window.FindName("CloseButton")
      $okButton = $window.FindName("OkButton")
      $rootBorder = $window.FindName("RootBorder")
      $iconEllipse = $window.FindName("IconEllipse")
      $iconText = $window.FindName("IconText")
      $headerDivider = $window.FindName("HeaderDivider")
      $footerDivider = $window.FindName("FooterDivider")

      if ($titleText) { $titleText.Text = $title }
      if ($subtitleText) { $subtitleText.Text = $subtitle }
      if ($messageText) {
        $messageText.Text = if ([string]::IsNullOrWhiteSpace($message)) { "" } else { $message }
      }

      if ($null -ne $popupConfig) {
        try {
          $widthValue = Get-ObjectProperty $popupConfig @("width")
          if ($null -ne $widthValue) {
            $w = [double]$widthValue
            if ($w -ge 240 -and $w -le 1200) { $window.Width = $w }
          }
        } catch {}

        try {
          $minHeightValue = Get-ObjectProperty $popupConfig @("minHeight", "min_height")
          if ($null -ne $minHeightValue) {
            $h = [double]$minHeightValue
            if ($h -ge 160 -and $h -le 1200) { $window.MinHeight = $h }
          }
        } catch {}

        try {
          $fontFamilyValue = Get-ObjectProperty $popupConfig @("fontFamily", "font_family")
          if (-not [string]::IsNullOrWhiteSpace($fontFamilyValue)) {
            $ff = New-Object System.Windows.Media.FontFamily -ArgumentList $fontFamilyValue.ToString()
            if ($titleText) { $titleText.FontFamily = $ff }
            if ($subtitleText) { $subtitleText.FontFamily = $ff }
            if ($messageText) { $messageText.FontFamily = $ff }
            if ($okButton) { $okButton.FontFamily = $ff }
          }
        } catch {}

        try {
          $titleSizeValue = Get-ObjectProperty $popupConfig @("titleFontSize", "title_font_size")
          if ($null -ne $titleSizeValue -and $titleText) { $titleText.FontSize = [double]$titleSizeValue }
        } catch {}

        try {
          $subtitleSizeValue = Get-ObjectProperty $popupConfig @("subtitleFontSize", "subtitle_font_size")
          if ($null -ne $subtitleSizeValue -and $subtitleText) { $subtitleText.FontSize = [double]$subtitleSizeValue }
        } catch {}

        try {
          $messageSizeValue = Get-ObjectProperty $popupConfig @("messageFontSize", "message_font_size")
          if ($null -ne $messageSizeValue -and $messageText) { $messageText.FontSize = [double]$messageSizeValue }
        } catch {}

        try {
          $titleColor = Get-ObjectProperty $popupConfig @("titleColor", "title_color")
          $b = New-SolidBrush $titleColor
          if ($null -ne $b -and $titleText) { $titleText.Foreground = $b }
        } catch {}

        try {
          $subtitleColor = Get-ObjectProperty $popupConfig @("subtitleColor", "subtitle_color")
          $b = New-SolidBrush $subtitleColor
          if ($null -ne $b -and $subtitleText) { $subtitleText.Foreground = $b }
        } catch {}

        try {
          $messageColor = Get-ObjectProperty $popupConfig @("messageColor", "message_color")
          $b = New-SolidBrush $messageColor
          if ($null -ne $b -and $messageText) { $messageText.Foreground = $b }
        } catch {}

        try {
          $bg = Get-ObjectProperty $popupConfig @("backgroundColor", "background_color")
          $b = New-SolidBrush $bg
          if ($null -ne $b -and $rootBorder) { $rootBorder.Background = $b }
        } catch {}

        try {
          $bc = Get-ObjectProperty $popupConfig @("borderColor", "border_color")
          $b = New-SolidBrush $bc
          if ($null -ne $b -and $rootBorder) { $rootBorder.BorderBrush = $b }
        } catch {}

        try {
          $dc = Get-ObjectProperty $popupConfig @("dividerColor", "divider_color")
          $b = New-SolidBrush $dc
          if ($null -ne $b) {
            if ($headerDivider) { $headerDivider.BorderBrush = $b }
            if ($footerDivider) { $footerDivider.BorderBrush = $b }
          }
        } catch {}

        try {
          $iconBg = Get-ObjectProperty $popupConfig @("iconBackgroundColor", "icon_background_color", "accentColor", "accent_color")
          $b = New-SolidBrush $iconBg
          if ($null -ne $b -and $iconEllipse) { $iconEllipse.Fill = $b }
        } catch {}

        try {
          $iconFg = Get-ObjectProperty $popupConfig @("iconTextColor", "icon_text_color")
          $b = New-SolidBrush $iconFg
          if ($null -ne $b -and $iconText) { $iconText.Foreground = $b }
        } catch {}

        try {
          $iconTextValue = Get-ObjectProperty $popupConfig @("iconText", "icon_text")
          if (-not [string]::IsNullOrWhiteSpace($iconTextValue) -and $iconText) { $iconText.Text = $iconTextValue.ToString() }
        } catch {}

        try {
          $accent = Get-ObjectProperty $popupConfig @("accentColor", "accent_color")
          $b = New-SolidBrush $accent
          if ($null -ne $b -and $okButton) { $okButton.Background = $b }
        } catch {}

        try {
          $okTextValue = Get-ObjectProperty $popupConfig @("okText", "ok_text")
          if (-not [string]::IsNullOrWhiteSpace($okTextValue) -and $okButton) { $okButton.Content = $okTextValue.ToString() }
        } catch {}
      }

      if ($rootBorder) {
        $cornerRadius = 14.0
        $updateClip = {
          try {
            $rect = New-Object System.Windows.Rect -ArgumentList 0, 0, $rootBorder.ActualWidth, $rootBorder.ActualHeight
            $rootBorder.Clip = New-Object System.Windows.Media.RectangleGeometry -ArgumentList $rect, $cornerRadius, $cornerRadius
          } catch {}
        }
        $rootBorder.Add_SizeChanged({ & $updateClip })
        $window.Add_Loaded({ & $updateClip })
      }

      if ($okButton) {
        if ([string]::IsNullOrWhiteSpace($okButton.Content)) { $okButton.Content = "OK" }
        $okButton.IsDefault = $true
        $okButton.Add_Click({ $window.Close() })
      }
      if ($closeButton) { $closeButton.Add_Click({ $window.Close() }) }

      $window.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $sender.Close() }
      })
      $window.Add_MouseLeftButtonDown({
        param($sender, $e)
        if ($e.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
          try { $sender.DragMove() } catch {}
        }
      })

      if (-not $noSound) {
        try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
      }

      $timer = $null
      if ($seconds -gt 0) {
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds($seconds)
        $timer.Add_Tick({
          $timer.Stop()
          $window.Close()
        })
        $timer.Start()
      }

      Log ("popup shown seconds={0}" -f $seconds)
      [void]$window.ShowDialog()
      Log "popup closed"
    } catch {
      Log ("popup wpf error: {0}" -f $_.Exception.Message)
      try {
        $wsh = New-Object -ComObject WScript.Shell
        [void]$wsh.Popup($body, $seconds, $title, 0x40)
        Log "popup closed (wsh)"
      } catch {
        Log ("popup fallback error: {0}" -f $_.Exception.Message)
      }
    }
    return
  }

  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  Add-Type -AssemblyName System.Drawing | Out-Null

  $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
  $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
  $notifyIcon.BalloonTipTitle = $title
  $notifyIcon.BalloonTipText = $body
  $notifyIcon.Visible = $true

  if (-not $noSound) {
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
  }

  $context = New-Object System.Windows.Forms.ApplicationContext

  $showTimer = New-Object System.Windows.Forms.Timer
  $showTimer.Interval = 150
  $showTimer.Add_Tick({
    $showTimer.Stop()
    try { $notifyIcon.ShowBalloonTip($seconds * 1000) } catch {}
    Log "balloon shown"
  })

  $exitTimer = New-Object System.Windows.Forms.Timer
  $exitTimer.Interval = ($seconds * 1000) + 1500
  $exitTimer.Add_Tick({
    $exitTimer.Stop()
    try { $notifyIcon.Visible = $false } catch {}
    try { $notifyIcon.Dispose() } catch {}
    try { $context.ExitThread() } catch {}
  })

  $showTimer.Start()
  $exitTimer.Start()

  [System.Windows.Forms.Application]::Run($context)
} catch {
  Log ("error: {0}" -f $_.Exception.Message)
} finally {
  try { if ($showTimer) { $showTimer.Dispose() } } catch {}
  try { if ($exitTimer) { $exitTimer.Dispose() } } catch {}
  try { if ($notifyIcon) { $notifyIcon.Dispose() } } catch {}
}
