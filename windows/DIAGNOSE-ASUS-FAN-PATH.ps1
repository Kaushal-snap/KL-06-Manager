# KL-06 read-only ASUS fan-control provider inventory for Windows.
# No EC/SMC writes, driver installation, registry modification, or fan commands.
$ErrorActionPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
$desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop)) { $desktop = $env:TEMP }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $desktop "KL06-ASUS-Fan-Diagnostic-$stamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$report = Join-Path $outDir 'ASUS-FAN-PATH.txt'
$lines = [System.Collections.Generic.List[string]]::new()
function Add-Section([string]$name) { $lines.Add(""); $lines.Add("--- $name ---") }
$lines.Add("KL-06 ASUS FAN PATH DIAGNOSTIC")
$lines.Add("Read-only inventory only. No hardware settings changed.")
Add-Section "Windows / device (serial numbers intentionally excluded)"
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$lines.Add("OS: $($os.Caption) $($os.Version) build $($os.BuildNumber)")
$lines.Add("Model: $($cs.Model)")
$lines.Add("BIOS manufacturer: $($bios.Manufacturer)")
$lines.Add("BIOS version: $($bios.SMBIOSBIOSVersion)")
$lines.Add("BIOS release date: $($bios.ReleaseDate)")
Add-Section "ASUS-related services"
$services = Get-CimInstance Win32_Service | Where-Object {
  $_.Name -match 'ASUS|ATK|ASUS' -or $_.DisplayName -match 'ASUS|ATK'
} | Sort-Object Name
if ($services) {
  foreach ($svc in $services) { $lines.Add("$($svc.Name) | $($svc.State) | $($svc.StartMode) | $($svc.DisplayName)") }
} else { $lines.Add("No ASUS/ATK services found.") }
Add-Section "ASUS System Control Interface signed driver"
$drivers = Get-CimInstance Win32_PnPSignedDriver | Where-Object {
  $_.DeviceName -match 'ASUS System Control Interface|ASUS System Control'
}
if ($drivers) {
  foreach ($d in $drivers) { $lines.Add("$($d.DeviceName) | version $($d.DriverVersion) | provider $($d.DriverProviderName) | date $($d.DriverDate)") }
} else { $lines.Add("ASUS System Control Interface driver not found by device name.") }
Add-Section "ASUS-related WMI class names (no instance data)"
$classes = @()
foreach ($ns in @('root/wmi','root/ASUS','root/ATK')) {
  try {
    $found = Get-CimClass -Namespace $ns -ErrorAction Stop | Where-Object { $_.CimClassName -match 'ASUS|ATK|WMNB|Fan|Thermal' }
    foreach ($c in $found) { $classes += "$ns : $($c.CimClassName)" }
  } catch { }
}
if ($classes.Count) { $classes | Sort-Object -Unique | ForEach-Object { $lines.Add($_) } }
else { $lines.Add("No matching WMI class names found in checked namespaces.") }
Add-Section "MyASUS package presence"
$apps = Get-AppxPackage -AllUsers -Name '*MyASUS*' | Select-Object -ExpandProperty Name -Unique
if ($apps) { foreach ($app in $apps) { $lines.Add($app) } } else { $lines.Add("MyASUS AppX package not found or not visible to this user.") }
Add-Section "Safety / interpretation"
$lines.Add("This inventory does not prove that a writable fan API exists.")
$lines.Add("Do not send serial numbers, passwords, raw EC dumps, or full registry exports.")
$lines.Add("A provider must be documented, model-compatible, and read-back verified before KL-06 enables manual fan control.")
[System.IO.File]::WriteAllLines($report, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Host "Diagnostic saved to: $report"
Write-Host "Open ASUS-FAN-PATH.txt and share its contents. This script did not change fan settings."
