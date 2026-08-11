# launcher.ps1 - Windows launcher (scaffold)
$ErrorActionPreference = 'Stop'

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir  = Join-Path $Root 'certifica-jar'
$Jar     = Join-Path $AppDir 'Certifica-32bits.jar'
$HashFile = Join-Path $AppDir 'Certifica-32bits.jar.sha256'
$Cache   = Join-Path $Root '.cache'
$JdkCache = Join-Path $Cache 'jdk8-x64'
$AdoptiumApi = 'https://api.adoptium.net/v3/binary/latest/8/ga/windows/x64/jdk/hotspot/normal/eclipse'

if (-not (Test-Path $Jar)) { throw "Certifica-32bits.jar not found at $Jar" }
if (-not (Test-Path $HashFile)) { throw "Hash file not found at $HashFile" }

$ExpectedHash = (Get-Content $HashFile | Select-Object -First 1).Split(' ')[0].Trim()
$ActualHash = (Get-FileHash -Algorithm SHA256 $Jar).Hash.ToLowerInvariant()
if ($ExpectedHash -ne $ActualHash) {
    throw "Hash verification FAILED. $Jar is corrupt or was modified. Expected $ExpectedHash, got $ActualHash."
}
Write-Host '[launcher] Hash OK'

function Get-JavaHome {
    if ($env:CERTIFICA_JAVA_HOME) {
        if (-not (Test-Path (Join-Path $env:CERTIFICA_JAVA_HOME 'bin\java.exe'))) {
            throw "CERTIFICA_JAVA_HOME set but no bin\java.exe there"
        }
        return $env:CERTIFICA_JAVA_HOME
    }
    if (Test-Path (Join-Path $JdkCache 'bin\java.exe')) { return $JdkCache }

    Write-Host '[launcher] Downloading Temurin JDK 8 (x64) for Windows...'
    New-Item -ItemType Directory -Force -Path $Cache | Out-Null
    $zip = Join-Path $Cache 'jdk8-x64.zip'
    Invoke-WebRequest -Uri $AdoptiumApi -OutFile $zip -MaximumRedirection 5
    Remove-Item -Recurse -Force $JdkCache -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $JdkCache
    Remove-Item $zip
    if (-not (Test-Path (Join-Path $JdkCache 'bin\java.exe'))) { throw 'Downloaded JDK is corrupt' }
    return $JdkCache
}

$JavaHome = Get-JavaHome
Write-Host "[launcher] Using JDK: $JavaHome"
Push-Location $AppDir
try {
    & (Join-Path $JavaHome 'bin\java.exe') -jar 'Certifica-32bits.jar' @args
} finally {
    Pop-Location
}
