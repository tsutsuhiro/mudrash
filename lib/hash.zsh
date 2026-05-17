# lib/hash.zsh — project key → hue ∈ [0, 360)
#
# Despite the .zsh extension, this file is POSIX-shell-compatible so that
# bats (which runs under bash) can source it directly. The .zsh suffix is
# project convention, not a syntax claim.
#
# Functions:
#   mudrash_hue <key>          → hue with knee correction applied
#   _mudrash_hue_raw <key>     → hue without correction (internal, exposed for tests)
#   _mudrash_apply_knee <hue>  → applies knee correction (internal, exposed for tests)

_mudrash_sha1() {
    # Read stdin, emit 40-char lowercase hex of SHA-1.
    # Prefer shasum (default on macOS) and fall back to sha1sum (Linux).
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 1 | awk '{print $1}'
    else
        sha1sum | awk '{print $1}'
    fi
}

_mudrash_apply_knee() {
    # Knee-zone correction: shift hues that fall in perceptually muddy bands.
    # 50–70   → +30 (avoids yellow-green sludge)
    # 270–290 → +25 (avoids hard-to-read reddish-purple)
    local h=$1
    if [ "$h" -ge 50 ] && [ "$h" -le 70 ]; then
        h=$(( (h + 30) % 360 ))
    elif [ "$h" -ge 270 ] && [ "$h" -le 290 ]; then
        h=$(( (h + 25) % 360 ))
    fi
    printf '%d\n' "$h"
}

_mudrash_hue_raw() {
    local key hex
    key=$1
    hex=$(printf '%s' "$key" | _mudrash_sha1 | cut -c1-4)
    printf '%d\n' "$(( 0x$hex % 360 ))"
}

mudrash_hue() {
    local raw
    raw=$(_mudrash_hue_raw "$1")
    _mudrash_apply_knee "$raw"
}
