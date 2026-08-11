#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
MAC_ZIP="$DIST_DIR/Certifica-macOS-x64.zip"
WIN_ZIP="$DIST_DIR/Certifica-Windows-x64.zip"
SUMS="$DIST_DIR/SHA256SUMS"

log()  { echo "[release] $*"; }
die()  { echo "[release] ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Uso: ./release.sh <version> [--dry-run]

Ejemplo: ./release.sh 1.0.0

- Verifica prerrequisitos (gh, repo, tag inexistente).
- Si faltan los zips en dist/, ejecuta ./make-dist.sh.
- Verifica dist/SHA256SUMS contra los zips.
- Crea el Release en GitHub con los zips + SHA256SUMS como assets.

--dry-run: hace todo menos crear el Release (muestra el comando).
EOF
  exit 1
}

[ $# -ge 1 ] || usage
VERSION="${1#v}"
DRY_RUN=0
[ "${2:-}" = "--dry-run" ] && DRY_RUN=1
TAG="v$VERSION"

case "$VERSION" in
  *[!0-9.]*|'') die "Version invalida: '$VERSION' (esperado: N.N.N)" ;;
esac

command -v gh >/dev/null 2>&1 || die "Instala GitHub CLI: https://cli.github.com"
gh auth status >/dev/null 2>&1 || die "gh no autenticado. Ejecuta: gh auth login"
git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1 || die "No es un repo git"

if git -C "$SCRIPT_DIR" ls-remote --tags origin "refs/tags/$TAG" | grep -q .; then
  die "El tag $TAG ya existe en origin"
fi
if git -C "$SCRIPT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
  die "El tag $TAG ya existe localmente"
fi

if git -C "$SCRIPT_DIR" status --porcelain | grep -q .; then
  log "AVISO: working tree sucio; el Release apuntara a HEAD de todos modos."
fi

if [ ! -f "$MAC_ZIP" ] || [ ! -f "$WIN_ZIP" ]; then
  log "Zips ausentes en dist/; ejecutando make-dist.sh..."
  "$SCRIPT_DIR/make-dist.sh"
fi

[ -f "$SUMS" ] || die "Falta $SUMS"
log "Verificando SHA256SUMS..."
(cd "$DIST_DIR" && shasum -a 256 -c SHA256SUMS >/dev/null) || die "SHA256SUMS no coincide con los zips"

NOTES="$DIST_DIR/release-notes-$TAG.md"
cat > "$NOTES" <<EOF
Paquetes portables de Certifica (SAT Mexico): incluyen la app y Temurin JRE 8 x64. No requieren instalar Java ni internet al ejecutar.

## Instalacion

1. Descarga el zip de tu sistema.
2. Descomprime.
3. macOS: doble clic en \`run.command\` (si Gatekeeper bloquea: clic derecho -> Abrir).
   Windows: doble clic en \`run.bat\`.

## Requisitos

- macOS: en Apple Silicon (M1/M2/M3/M4) se requiere Rosetta 2: \`softwareupdate --install-rosetta --agree-to-license\`
- Windows: 64 bits. El paquete de Windows no ha sido probado aún (scaffold).

## Verificacion de integridad

\`\`\`
$(cd "$DIST_DIR" && shasum -a 256 Certifica-macOS-x64.zip Certifica-Windows-x64.zip)
\`\`\`
EOF

TARGET="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
log "Tag: $TAG -> $TARGET"

if [ "$DRY_RUN" = 1 ]; then
  log "DRY-RUN. Comando que se ejecutaria:"
  echo "gh release create \"$TAG\" \"$MAC_ZIP\" \"$WIN_ZIP\" \"$SUMS\" --title \"$TAG\" --notes-file \"$NOTES\" --target \"$TARGET\""
  exit 0
fi

gh release create "$TAG" "$MAC_ZIP" "$WIN_ZIP" "$SUMS" \
  --title "$TAG" --notes-file "$NOTES" --target "$TARGET"

REPO_URL="$(gh repo view --json url -q .url 2>/dev/null || echo 'https://github.com/(repo)')"
log "Release creado: $REPO_URL/releases/tag/$TAG"
