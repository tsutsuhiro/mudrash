#!/bin/sh
# install.sh — bootstrap installer for mudrash
#
# Run from a clone of the repo:    ./install.sh
# Or via the hosted one-liner:
#   curl -fsSL https://raw.githubusercontent.com/tsutsuhiro/mudrash/main/install.sh | sh
#
# Idempotent. Adds a marker block to ~/.zshrc that sources mudrash.zsh and
# prepends $INSTALL_DIR/bin to PATH so `mudrash` is callable.

set -eu

INSTALL_PRIMARY="$HOME/.local/share/mudrash"
INSTALL_FALLBACK="$HOME/.mudrash"
MARKER_OPEN='# >>> mudrash >>>'
MARKER_CLOSE='# <<< mudrash <<<'

# --- Locate source ---------------------------------------------------------

src_dir=$(cd "$(dirname "$0")" && pwd)

for required in \
    "$src_dir/mudrash.zsh" \
    "$src_dir/lib/hash.zsh" \
    "$src_dir/lib/color.zsh" \
    "$src_dir/bin/mudrash"
do
    if [ ! -f "$required" ]; then
        printf 'install.sh: missing %s\n' "$required" >&2
        printf 'Run install.sh from a clone of the mudrash repository.\n' >&2
        exit 1
    fi
done

# --- Shell check -----------------------------------------------------------

case "${SHELL:-}" in
    */zsh|zsh) ;;
    *)
        printf 'install.sh: \$SHELL is "%s"; mudrash supports zsh only.\n' "${SHELL:-(unset)}" >&2
        printf 'bash and fish support is planned. Set SHELL to your zsh path or wait.\n' >&2
        exit 1
        ;;
esac

# --- Pick install dir ------------------------------------------------------

if mkdir -p "$INSTALL_PRIMARY" 2>/dev/null; then
    install_dir=$INSTALL_PRIMARY
elif mkdir -p "$INSTALL_FALLBACK" 2>/dev/null; then
    install_dir=$INSTALL_FALLBACK
else
    printf 'install.sh: could not create install dir at %s or %s\n' "$INSTALL_PRIMARY" "$INSTALL_FALLBACK" >&2
    exit 1
fi

# --- Copy files ------------------------------------------------------------

cp "$src_dir/mudrash.zsh" "$install_dir/mudrash.zsh"

mkdir -p "$install_dir/lib"
# Clean any stale lib/*.zsh from a previous install before copying.
rm -f "$install_dir/lib/"*.zsh 2>/dev/null || true
cp "$src_dir/lib/"*.zsh "$install_dir/lib/"

mkdir -p "$install_dir/bin"
cp "$src_dir/bin/mudrash" "$install_dir/bin/mudrash"
chmod +x "$install_dir/bin/mudrash"

# Copy install.sh so `mudrash install` can re-invoke us later.
cp "$src_dir/install.sh" "$install_dir/install.sh"
chmod +x "$install_dir/install.sh"

# --- Edit .zshrc -----------------------------------------------------------

rcfile="$HOME/.zshrc"
touch "$rcfile"

# Remove any existing mudrash block (idempotent re-install).
if grep -qF "$MARKER_OPEN" "$rcfile"; then
    tmp=$(mktemp)
    awk -v open="$MARKER_OPEN" -v endmark="$MARKER_CLOSE" '
        $0 == open    { skip = 1; next }
        skip && $0 == endmark { skip = 0; next }
        skip          { next }
        { print }
    ' "$rcfile" > "$tmp"
    # Collapse any blank-line drift left behind by the removal.
    awk 'NF { blank=0; print; next } { if (!blank) print; blank=1 }' "$tmp" > "$rcfile"
    rm -f "$tmp"
    replaced=1
else
    replaced=0
fi

# Append the fresh block. Heredoc with unquoted EOF so $install_dir expands;
# \$PATH is escaped so it lands as the literal `$PATH` for zsh to expand
# at source-time, not now.
cat <<EOF >> "$rcfile"

$MARKER_OPEN
export PATH="$install_dir/bin:\$PATH"
source "$install_dir/mudrash.zsh"
$MARKER_CLOSE
EOF

# --- Done message ----------------------------------------------------------

if [ "$replaced" -eq 1 ]; then
    printf 'mudrash re-installed at %s\n' "$install_dir"
else
    printf 'mudrash installed at %s\n' "$install_dir"
fi
printf 'Reload your shell or run:    source ~/.zshrc\n'
