param(
    [string]$SourceDir = 'C:\src',
    [string]$WorkDir = 'C:\work\tor-static',
    [string]$OutputDir = 'C:\out'
)

$ErrorActionPreference = 'Stop'

function Assert-PathExists {
    param([string]$PathToCheck, [string]$Message)

    if (-not (Test-Path -LiteralPath $PathToCheck)) {
        throw $Message
    }
}

# Build in a disposable workspace so host mounts stay read-only and clean.
if (Test-Path -LiteralPath $WorkDir) {
    Remove-Item -LiteralPath $WorkDir -Recurse -Force
}
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Assert-PathExists -PathToCheck $SourceDir -Message "Source directory not found: $SourceDir"

# Robocopy preserves timestamps and handles large trees better than Copy-Item for Windows containers.
$excludeDirs = @('.git', 'dist')
$robocopyArgs = @($SourceDir, $WorkDir, '/E', '/R:2', '/W:2', '/NFL', '/NDL', '/NJH', '/NJS')
foreach ($dir in $excludeDirs) {
    $robocopyArgs += '/XD'
    $robocopyArgs += (Join-Path $SourceDir $dir)
}
& robocopy @robocopyArgs | Out-Null
if ($LASTEXITCODE -gt 7) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

Set-Location -LiteralPath $WorkDir

Assert-PathExists -PathToCheck (Join-Path $WorkDir 'openssl\Configure') -Message 'Submodules are missing. Run: git submodule update --init --recursive'
Assert-PathExists -PathToCheck (Join-Path $WorkDir 'libevent\autogen.sh') -Message 'Submodules are missing. Run: git submodule update --init --recursive'
Assert-PathExists -PathToCheck (Join-Path $WorkDir 'tor\configure.ac') -Message 'Submodules are missing. Run: git submodule update --init --recursive'
Assert-PathExists -PathToCheck (Join-Path $WorkDir 'xz\configure.ac') -Message 'Submodules are missing. Run: git submodule update --init --recursive'
Assert-PathExists -PathToCheck (Join-Path $WorkDir 'zlib\configure') -Message 'Submodules are missing. Run: git submodule update --init --recursive'

$bash = 'C:\msys64\usr\bin\bash.exe'
$bashScript = @'
set -euo pipefail
export MSYSTEM=MINGW64
export CHERE_INVOKING=1
export PATH=/mingw64/bin:/usr/bin:$PATH
/c/go/bin/go.exe version
/c/go/bin/go.exe run build.go -verbose build-all
/c/go/bin/go.exe run build.go package-libs
/c/go/bin/go.exe run build.go show-libs > show-libs.txt
'@

& $bash -lc $bashScript

Copy-Item -LiteralPath (Join-Path $WorkDir 'libs.zip') -Destination (Join-Path $OutputDir 'tor-static-windows-amd64.zip') -Force
Copy-Item -LiteralPath (Join-Path $WorkDir 'libs.tar.gz') -Destination (Join-Path $OutputDir 'tor-static-windows-amd64.tar.gz') -Force
Copy-Item -LiteralPath (Join-Path $WorkDir 'show-libs.txt') -Destination (Join-Path $OutputDir 'show-libs.txt') -Force
