#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$DIR/certifica-jar"
JAVA="$DIR/jre/bin/java"

warn() { echo "[Certifica] $*" >&2; }
die()  { echo "[Certifica] ERROR: $*" >&2; exit 1; }

MACHINE="$(uname -m)"
if [ "$MACHINE" = "arm64" ]; then
  if ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    die "Rosetta 2 no instalado. Ejecuta:  softwareupdate --install-rosetta --agree-to-license  y reintenta. (La app requiere JVM x64; los libs JNA no tienen slice arm64.)"
  fi
fi

[ -x "$JAVA" ] || die "No se encontro el JRE incluido (jre/bin/java). Re-descarga el paquete completo."
file "$JAVA" | grep -q x86_64 || die "El JRE incluido no es x86_64. Re-descarga el paquete."

xattr -dr com.apple.quarantine "$DIR" 2>/dev/null || true

[ -f "$APP_DIR/Certifica-32bits.jar" ] || die "Falta certifica-jar/Certifica-32bits.jar"
(cd "$APP_DIR" && shasum -a 256 -c Certifica-32bits.jar.sha256 >/dev/null 2>&1) \
  || die "Verificacion SHA-256 FALLO. El jar esta corrupto o fue modificado. Re-descarga el paquete."
warn "Integridad verificada (SHA-256 OK)"

cd "$APP_DIR"
exec "$JAVA" -Xdock:name="Certifica" -Dapple.awt.graphics.UseQuartz=true -jar Certifica-32bits.jar "$@"
