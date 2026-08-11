#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/certifica-jar"
JAR="$APP_DIR/Certifica-32bits.jar"
SRC_DIR="$SCRIPT_DIR/dist-src"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$DIST_DIR/build"
VERSION="${1:-}"

ADOPTIUM="https://api.adoptium.net/v3/binary/latest/8/ga"

log() { echo "[make-dist] $*"; }
die() { echo "[make-dist] ERROR: $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl requerido"
command -v zip  >/dev/null 2>&1 || die "zip requerido"
command -v tar  >/dev/null 2>&1 || die "tar requerido"
command -v unzip >/dev/null 2>&1 || die "unzip requerido"

[ -f "$JAR" ] || die "No se encuentra el jar: $JAR"
[ -d "$SRC_DIR" ] || die "No se encuentra dist-src/"

log "Verificando integridad del jar..."
(cd "$APP_DIR" && shasum -a 256 -c Certifica-32bits.jar.sha256 >/dev/null) \
  || die "La verificacion SHA-256 del jar FALLO. Aborta."

SUFFIX=""
[ -n "$VERSION" ] && SUFFIX="-$VERSION"

fetch_jre() { # $1=os (mac|windows)  $2=out-file
  local os="$1" out="$2" api loc expected actual
  api="$ADOPTIUM/$os/x64/jre/hotspot/normal/eclipse"
  log "Descargando Temurin JRE 8 x64 ($os)..."
  loc="$(curl -fsSIL "$api" 2>/dev/null | awk 'tolower($1)=="location:" {print $2}' | tr -d '\r' | grep '/releases/download/' | head -n 1)" || true
  [ -n "$loc" ] || die "No se pudo resolver la URL del asset ($os) desde $api"
  curl -fsSL --retry 3 -o "$out" "$loc" || die "Fallo la descarga del JRE ($os) desde $loc"
  log "Verificando checksum del JRE ($os)..."
  expected="$(curl -fsSL "$loc.sha256.txt" | awk '{print $1}')" \
    || die "No se encontro el archivo .sha256.txt para $loc"
  actual="$(shasum -a 256 "$out" | awk '{print $1}')"
  [ "$expected" = "$actual" ] || die "Checksum del JRE ($os) NO coincide"
}

copy_app() { # $1=stage-dir
  mkdir -p "$1/certifica-jar"
  cp "$JAR" "$APP_DIR/Certifica-32bits.jar.sha256" "$1/certifica-jar/"
  cp "$SRC_DIR/LEEME.txt" "$1/LEEME.txt"
}

build_mac() {
  local name="Certifica-macOS-x64$SUFFIX"
  local stage="$BUILD_DIR/$name"
  local archive="$BUILD_DIR/jre-mac.tar.gz"
  local tmp="$BUILD_DIR/jre-mac-extract"
  local home

  log "Armando $name..."
  fetch_jre mac "$archive"
  rm -rf "$tmp" && mkdir -p "$tmp"
  tar -xzf "$archive" -C "$tmp"
  home="$(find "$tmp" -maxdepth 3 -type d -path '*/Contents/Home' | head -n 1)"
  [ -n "$home" ] && [ -x "$home/bin/java" ] || die "Layout inesperado del JRE mac"

  rm -rf "$stage" && mkdir -p "$stage"
  mv "$home" "$stage/jre"
  copy_app "$stage"
  cp "$SRC_DIR/run.command" "$stage/run.command"
  chmod +x "$stage/run.command"

  (cd "$BUILD_DIR" && zip -qry "$DIST_DIR/$name.zip" "$name")
  rm -rf "$stage" "$tmp" "$archive"
  log "Listo: dist/$name.zip"
}

build_win() {
  local name="Certifica-Windows-x64$SUFFIX"
  local stage="$BUILD_DIR/$name"
  local archive="$BUILD_DIR/jre-win.zip"
  local tmp="$BUILD_DIR/jre-win-extract"
  local jre

  log "Armando $name..."
  fetch_jre windows "$archive"
  rm -rf "$tmp" && mkdir -p "$tmp"
  unzip -q "$archive" -d "$tmp"
  jre="$(find "$tmp" -maxdepth 3 -type f -name java.exe -path '*/bin/java.exe' | head -n 1)"
  [ -n "$jre" ] || die "Layout inesperado del JRE windows"
  jre="$(dirname "$(dirname "$jre")")"

  rm -rf "$stage" && mkdir -p "$stage"
  mv "$jre" "$stage/jre"
  copy_app "$stage"
  awk '{ printf "%s\r\n", $0 }' "$SRC_DIR/run.bat" > "$stage/run.bat"

  (cd "$BUILD_DIR" && zip -qry "$DIST_DIR/$name.zip" "$name")
  rm -rf "$stage" "$tmp" "$archive"
  log "Listo: dist/$name.zip"
}

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

build_mac
build_win

log "Generando dist/SHA256SUMS..."
(cd "$DIST_DIR" && rm -f SHA256SUMS && shasum -a 256 *.zip > SHA256SUMS)

rm -rf "$BUILD_DIR"
log "Todo listo en dist/:"
ls -lh "$DIST_DIR"
