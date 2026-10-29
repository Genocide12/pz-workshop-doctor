#Requires -Version 5.1
<#
    Local EXE build for PZ Workshop Doctor (for Windows machines).
    Produces PZWorkshopDoctor.exe next to this script using ps2exe.

    Usage:
        powershell -ExecutionPolicy Bypass -File .\build-exe.ps1

    Note: ps2exe binaries occasionally trip SmartScreen / antivirus
    heuristics ("More info -> Run anyway"). That is a known property of
    every ps2exe-built tool, not something specific to this app.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$src  = Join-Path $root 'PZ-WorkshopDoctor.ps1'
$out  = Join-Path $root 'PZWorkshopDoctor.exe'

if (-not (Test-Path -LiteralPath $src)) { throw "PZ-WorkshopDoctor.ps1 not found next to build-exe.ps1" }
if (-not (Get-Module -ListAvailable ps2exe)) {
    Write-Output 'Installing ps2exe (CurrentUser scope)...'
    Install-Module ps2exe -Scope CurrentUser -Force
}

$version = '1.0'
foreach ($line in (Get-Content -LiteralPath $src -TotalCount 40)) {
    if ($line -match "\`$Script:Version\s*=\s*'([^']+)'") { $version = $Matches[1]; break }
}

# Splatting must be a HASHTABLE: an array splat binds positionally and
# '-noConsole' would land in the int-typed -lcid parameter.
$p = @{
    inputFile   = $src
    outputFile  = $out
    icon        = (Join-Path $root 'assets\icon.ico')
    noConsole   = $true
    noError     = $true
    STA         = $true
    title       = 'PZ Workshop Doctor'
    description = 'Workshop mod doctor for Project Zomboid: scans Workshop folders, checks saves, finds broken mods (unofficial community tool, MIT)'
    company     = 'Genocide12'
    product     = 'PZ Workshop Doctor'
    copyright   = '(c) 2026 Genocide12 (MIT)'
    version     = $version
}
try { Invoke-PS2EXE @p }
catch {
    Write-Output "retry without -STA: $($_.Exception.Message)"
    $p.Remove('STA')
    try { Invoke-PS2EXE @p }
    catch {
        Write-Output "retry minimal: $($_.Exception.Message)"
        Invoke-PS2EXE -inputFile $src -outputFile $out -noConsole
    }
}
if (-not (Test-Path -LiteralPath $out)) { throw 'exe was not produced' }
$exe = Get-Item -LiteralPath $out
Write-Output ("Built: {0} ({1} bytes, v{2})" -f $exe.FullName, $exe.Length, $version)
