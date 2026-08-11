#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/certifica-jar"
JAR="$APP_DIR/Certifica-32bits.jar"
HASH_FILE="$APP_DIR/Certifica-32bits.jar.sha256"
CACHE_DIR="$SCRIPT_DIR/.cache"
JDK_CACHE="$CACHE_DIR/jdk8-x64"
ADOPTIUM_API="https://api.adoptium.net/v3/binary/latest/8/ga/mac/x64/jdk/hotspot/normal/eclipse"

warn() { echo "[launcher] $*" >&2; }
die()  { echo "[launcher] ERROR: $*" >&2; exit 1; }

MACHINE="$(uname -m)"
if [ "$MACHINE" = "arm64" ]; then
  if ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    die "Rosetta 2 not installed. Run:  softwareupdate --install-rosetta --agree-to-license   then retry. (The app needs an x64 JVM; JNA native libs have no arm64 slice.)"
  fi
fi

verify_jdk() {
  local java="$1/bin/java"
  [ -x "$java" ] || die "No 'bin/java' found in $1"
  if ! file "$java" | grep -q x86_64; then
    die "JDK at $1 is not x86_64. JNA native libs require an x64 JVM (run under Rosetta on Apple Silicon). Set CERTIFICA_JAVA_HOME to a JDK 8 x64 build."
  fi
}

download_jdk() {
  warn "Downloading Temurin JDK 8 (x64) for macOS..."
  mkdir -p "$CACHE_DIR"
  local tmp="$CACHE_DIR/jdk8-x64.tar.gz"
  curl -fL --retry 3 -o "$tmp" "$ADOPTIUM_API" || die "JDK download failed from $ADOPTIUM_API"
  rm -rf "$JDK_CACHE"
  mkdir -p "$JDK_CACHE"
  tar -xzf "$tmp" -C "$JDK_CACHE" --strip-components=1
  rm -f "$tmp"
  [ -x "$JDK_CACHE/Contents/Home/bin/java" ] || die "Downloaded JDK is corrupt (no Contents/Home/bin/java)."
  echo "$JDK_CACHE/Contents/Home"
}

find_jdk() {
  if [ -n "${CERTIFICA_JAVA_HOME:-}" ]; then
    [ -x "$CERTIFICA_JAVA_HOME/bin/java" ] || die "CERTIFICA_JAVA_HOME set but no bin/java there: $CERTIFICA_JAVA_HOME"
    echo "$CERTIFICA_JAVA_HOME"
    return
  fi
  if [ -x "$JDK_CACHE/Contents/Home/bin/java" ]; then
    echo "$JDK_CACHE/Contents/Home"
    return
  fi
  download_jdk
}

[ -f "$JAR" ] || die "Certifica-32bits.jar not found at $JAR"
[ -f "$HASH_FILE" ] || die "Hash file not found at $HASH_FILE"

if ! (cd "$APP_DIR" && shasum -a 256 -c Certifica-32bits.jar.sha256 >/dev/null 2>&1); then
  die "Hash verification FAILED. $JAR is corrupt or was modified. Re-download the original jar or regenerate the hash."
fi
warn "Hash OK"

if xattr "$JAR" 2>/dev/null | grep -q quarantine; then
  warn "Stripping quarantine flag from $JAR"
  xattr -dr com.apple.quarantine "$JAR"
fi

JAVA_HOME="$(find_jdk)"
verify_jdk "$JAVA_HOME"
warn "Using JDK: $JAVA_HOME"

cd "$APP_DIR"
exec "$JAVA_HOME/bin/java" -Xdock:name="Certifica-32bits" -Dapple.awt.graphics.UseQuartz=true -jar Certifica-32bits.jar "$@"
