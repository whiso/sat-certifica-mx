# sat-certifica-mx

Launcher para `certifica-jar/Certifica-32bits.jar` (SAT), app Java 8 legacy con Swing/SWT, en Apple Silicon y Windows.

## Descarga directa (recomendado para usuarios)

Paquetes portables con Java incluido (Temurin JRE 8 x64): no instalan nada, no requieren internet al ejecutar.

1. Descarga el zip para tu sistema desde [Releases](../../releases):
   - macOS: `Certifica-macOS-x64.zip`
   - Windows: `Certifica-Windows-x64.zip`
2. Descomprime y ejecuta `run.command` (macOS) o `run.bat` (Windows). Ver `LEEME.txt` dentro del zip.

En Apple Silicon se requiere Rosetta 2 (una sola vez): `softwareupdate --install-rosetta --agree-to-license`.

### Generar los zips (maintainers)

```bash
./make-dist.sh [version]   # escribe dist/*.zip + dist/SHA256SUMS
```

`make-dist.sh` verifica el SHA-256 del jar, descarga Temurin JRE 8 x64 (mac + windows) desde Adoptium verificando checksums, y arma cada zip con `jre/ + certifica-jar/ + launcher + LEEME.txt`. Para publicar: `./release.sh <version>` (requiere `gh auth login`; usa `--dry-run` para simular). Sube los zips y `SHA256SUMS` como assets del Release en GitHub.

## Launchers del repo (descargan el JDK la primera vez)

### macOS

```bash
./launcher.sh
```

El launcher:
- Detecta arm64 → verifica Rosetta 2 (instalable con `softwareupdate --install-rosetta --agree-to-license`).
- Busca JDK 8 **x64** en este orden:
  1. `$CERTIFICA_JAVA_HOME` (override explícito)
  2. `.cache/jdk8-x64/` (Temurin ya descargado)
  3. Descarga Temurin JDK 8 x64 desde Adoptium a `.cache/`
- Rechaza JDK arm64: los libs nativos JNA del jar no tienen slice arm64; el JVM debe ser x64 bajo Rosetta.
- Quita flag `com.apple.quarantine` de `Certifica-32bits.jar`.
- Verifica integridad del jar contra `certifica-jar/Certifica-32bits.jar.sha256` (SHA-256) antes de ejecutarlo. Si falla, aborta con error.

#### Por qué JDK 8 x64 + Rosetta

El jar incluye JNA (`libjnidispatch.jnilib` i386/x86_64/ppc, sin arm64) y SWT/DJ Native Swing. JVM nativo arm64 crashea con `UnsatisfiedLinkError`. Con JDK 8 x64 bajo Rosetta funciona: GUI Aqua, acceso a archivos y generación de llave con mouse.

#### JDK alternativo

```bash
CERTIFICA_JAVA_HOME=/ruta/al/jdk/Contents/Home ./launcher.sh
```

Temurin (OpenJDK, GPLv2+CE) es suficiente: la app no usa JavaFX ni extensiones propietarias de Oracle, y el crypto ilimitado está activo por defecto desde JDK 8u161. Se usa Temurin exclusivamente para evitar la licencia OTN de Oracle (no redistribuible).

### Windows (scaffold)

```bat
certifica-jar\run.bat
rem o
powershell -ExecutionPolicy Bypass -File launcher.ps1
```

Mismo orden de búsqueda de JDK: `CERTIFICA_JAVA_HOME` → `.cache\jdk8-x64\` (Temurin win x64) → `java` del PATH. El jar trae los libs JNA/SWT win32-x86-64, por lo que debería correr sin cambios. No probado aún.

## Verificación de integridad

El launcher verifica el SHA-256 del jar antes de ejecutar. Archivo de hash: `certifica-jar/Certifica-32bits.jar.sha256`.

Regenerar tras reemplazar el jar:

```bash
cd certifica-jar
shasum -a 256 Certifica-32bits.jar > Certifica-32bits.jar.sha256
```

Verificación manual:

```bash
cd certifica-jar && shasum -a 256 -c Certifica-32bits.jar.sha256
```

Windows (PowerShell): `Get-FileHash -Algorithm SHA256 certifica-jar\Certifica-32bits.jar`

## Docker

Posible pero no recomendado para uso interactivo: requiere XQuartz + `DISPLAY`, y los hooks nativos de mouse (entrada de entropía para la llave) fallan en contenedor. Solo tiene sentido para procesamiento headless (Xvfb + xdotool), no para generar llaves con mouse.

## Troubleshooting

- **`Rosetta 2 not installed`**: `softwareupdate --install-rosetta --agree-to-license`
- **`is not x86_64`**: el JDK detectado es arm64; apunta `CERTIFICA_JAVA_HOME` a un JDK 8 x64.
- **Bloqueado por Gatekeeper**: el launcher quita el quarantine automáticamente; si sigue bloqueado: `xattr -dr com.apple.quarantine certifica-jar/Certifica-32bits.jar`
- **Crashes con `UnsatisfiedLinkError`**: confirmar que el JDK usado es x86_64 (`file $(dirname $(which java))/java`).
