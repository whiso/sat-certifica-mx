param([string]$AppDir = '')

$ErrorActionPreference = 'Stop'

$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $AppDir) { $AppDir = Join-Path $root 'certifica-jar' }
$jar     = Join-Path $AppDir 'Certifica-64bits.jar'
$hashTxt = Join-Path $AppDir 'Certifica-64bits.jar.sha256'

if (-not (Test-Path $jar)) {
    Write-Host '[Certifica] ERROR: no se encuentra certifica-jar\Certifica-64bits.jar'
    exit 1
}
if (-not (Test-Path $hashTxt)) {
    Write-Host '[Certifica] ERROR: no se encuentra certifica-jar\Certifica-64bits.jar.sha256'
    exit 1
}

$expected = ((Get-Content -Raw $hashTxt) -split '\s+')[0].Trim().ToLowerInvariant()
$actual   = (Get-FileHash -Algorithm SHA256 $jar).Hash.ToLowerInvariant()

if ($expected -ne $actual) {
    Write-Host '[Certifica] ERROR: verificacion SHA-256 FALLO. El jar esta corrupto o fue modificado. Re-descarga el paquete.'
    Write-Host "  esperado: $expected"
    Write-Host "  obtenido: $actual"
    exit 1
}

Write-Host '[Certifica] Integridad verificada (SHA-256 OK)'
exit 0
