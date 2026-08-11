# make-dist.ps1 - arma el paquete portable de Windows (Windows-only build)
# Uso: powershell -ExecutionPolicy Bypass -File make-dist.ps1 [-Version 1.0.0]
#
# Equivalente Windows de make-dist.sh: verifica el jar, descarga Temurin JRE 8
# x64 (Adoptium) verificando checksum, y genera dist\Certifica-Windows-x64.zip.
param(
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir   = Join-Path $Root 'certifica-jar'
$Jar      = Join-Path $AppDir 'Certifica-64bits.jar'
$HashFile = Join-Path $AppDir 'Certifica-64bits.jar.sha256'
$SrcDir   = Join-Path $Root 'dist-src'
$DistDir  = Join-Path $Root 'dist'
$BuildDir = Join-Path $DistDir 'build'
$Adoptium = 'https://api.adoptium.net/v3/binary/latest/8/ga'

function Log($msg)  { Write-Host "[make-dist] $msg" }
function Die($msg)  { Write-Error "[make-dist] ERROR: $msg"; exit 1 }

if (-not (Test-Path $Jar))      { Die "No se encuentra el jar: $Jar" }
if (-not (Test-Path $HashFile)) { Die "No se encuentra el hash: $HashFile" }
if (-not (Test-Path $SrcDir))   { Die 'No se encuentra dist-src\' }

Log 'Verificando integridad del jar...'
$ExpectedJar = ((Get-Content $HashFile | Select-Object -First 1) -split '\s+')[0].Trim().ToLowerInvariant()
$ActualJar   = (Get-FileHash -Algorithm SHA256 $Jar).Hash.ToLowerInvariant()
if ($ExpectedJar -ne $ActualJar) { Die 'La verificacion SHA-256 del jar FALLO. Aborta.' }

$Suffix = ''
if ($Version) { $Suffix = "-$Version" }

# Sigue redirecciones sin descargar hasta hallar la URL /releases/download/ de GitHub
function Get-ReleaseAssetUrl($apiUrl) {
    $url = $apiUrl
    for ($i = 0; $i -lt 6; $i++) {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.AllowAutoRedirect = $false
        $req.UserAgent = 'certifica-make-dist'
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $location = $resp.Headers['Location']
        $resp.Close()
        if ($code -ge 300 -and $code -lt 400 -and $location) {
            if ($location -match '/releases/download/') { return $location }
            $url = $location
            continue
        }
        return $null
    }
    return $null
}

function Fetch-Jre($outFile) {
    $api = "$Adoptium/windows/x64/jre/hotspot/normal/eclipse"
    Log 'Descargando Temurin JRE 8 x64 (windows)...'
    $loc = Get-ReleaseAssetUrl $api
    if (-not $loc) { Die "No se pudo resolver la URL del asset desde $api" }
    Invoke-WebRequest -Uri $loc -OutFile $outFile -MaximumRedirection 5
    Log 'Verificando checksum del JRE (windows)...'
    $sumTxt  = (Invoke-WebRequest -Uri "$loc.sha256.txt" -UseBasicParsing).Content
    if ($sumTxt -is [byte[]]) { $sumTxt = [System.Text.Encoding]::UTF8.GetString($sumTxt) }
    $expected = ($sumTxt -split '\s+')[0].Trim().ToLowerInvariant()
    $actual   = (Get-FileHash -Algorithm SHA256 $outFile).Hash.ToLowerInvariant()
    if ($expected -ne $actual) { Die 'Checksum del JRE (windows) NO coincide' }
}

$Name  = "Certifica-Windows-x64$Suffix"
$Stage = Join-Path $BuildDir $Name

Remove-Item -Recurse -Force $BuildDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

$Archive = Join-Path $BuildDir 'jre-win.zip'
$Tmp     = Join-Path $BuildDir 'jre-win-extract'

Fetch-Jre $Archive
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
Expand-Archive -Path $Archive -DestinationPath $Tmp
$JavaExe = Get-ChildItem -Path $Tmp -Recurse -Filter 'java.exe' |
    Where-Object { $_.Directory.Name -eq 'bin' } | Select-Object -First 1
if (-not $JavaExe) { Die 'Layout inesperado del JRE windows' }
Move-Item -Path $JavaExe.Directory.Parent.FullName -Destination (Join-Path $Stage 'jre')

New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'certifica-jar') | Out-Null
Copy-Item $Jar      (Join-Path $Stage 'certifica-jar\Certifica-64bits.jar')
Copy-Item $HashFile (Join-Path $Stage 'certifica-jar\Certifica-64bits.jar.sha256')
Copy-Item (Join-Path $SrcDir 'LEEME.txt') (Join-Path $Stage 'LEEME.txt')

# run.bat / check-hash.ps1 del repo pueden tener finales de linea LF; convertir a CRLF
$BatRaw  = Get-Content -Raw -Path (Join-Path $SrcDir 'run.bat')
$BatCrlf = $BatRaw -replace "`r`n", "`n" -replace "`n", "`r`n"
[System.IO.File]::WriteAllText((Join-Path $Stage 'run.bat'), $BatCrlf, [System.Text.Encoding]::ASCII)
$PsRaw  = Get-Content -Raw -Path (Join-Path $SrcDir 'check-hash.ps1')
$PsCrlf = $PsRaw -replace "`r`n", "`n" -replace "`n", "`r`n"
[System.IO.File]::WriteAllText((Join-Path $Stage 'check-hash.ps1'), $PsCrlf, [System.Text.Encoding]::ASCII)

Log "Armando $Name.zip..."
$ZipPath = Join-Path $DistDir "$Name.zip"
Remove-Item $ZipPath -ErrorAction SilentlyContinue
Compress-Archive -Path $Stage -DestinationPath $ZipPath

Log 'Generando dist\SHA256SUMS...'
$SumsPath = Join-Path $DistDir 'SHA256SUMS'
Get-ChildItem -Path $DistDir -Filter '*.zip' | ForEach-Object {
    $h = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$h  $($_.Name)"
} | Set-Content -Path $SumsPath -Encoding ASCII

Remove-Item -Recurse -Force $BuildDir -ErrorAction SilentlyContinue
Log "Todo listo en dist\:"
Get-ChildItem $DistDir | Format-Table Name, Length
