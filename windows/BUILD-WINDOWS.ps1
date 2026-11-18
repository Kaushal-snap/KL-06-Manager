# Normal-user source build only. No app install, admin elevation or publication.
[CmdletBinding()]param([ValidateSet('win-x64','win-arm64')][string]$Runtime='win-x64')
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
if($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows){throw 'Use PowerShell on Windows for this owner build. A Linux cross-compile is not Windows testing.'}
if([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run without administrator elevation.'}
if(-not (Get-Command dotnet -ErrorAction SilentlyContinue)){throw 'Install/configure a trusted .NET 10 SDK separately. No SDK was downloaded by this script.'}
$project=Join-Path $PSScriptRoot 'KL06.Windows/KL06.Windows.csproj';$output=Join-Path $PSScriptRoot ('Local-build/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+$Runtime)
& dotnet restore $project --locked-mode -p:SelfContained=false
if($LASTEXITCODE -ne 0){throw 'Locked dependency restore failed; nothing was published.'}
& dotnet publish $project -c Release -r $Runtime --self-contained false --no-restore -p:PublishSingleFile=false -o $output
if($LASTEXITCODE -ne 0){throw 'Windows source build failed; inspect the local build output.'}
Write-Host "Owner-testing app directory: $output"
Write-Host 'Requires an already-installed .NET 10 Desktop Runtime and Microsoft Edge WebView2 runtime. Neither runtime is bundled/auto-installed. Unsigned local build; no SmartScreen/security bypass. Test before approving a ZIP. Nothing was uploaded.'
