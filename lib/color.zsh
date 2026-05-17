# lib/color.zsh — HSL → hex (6-digit, lowercase, no '#')
#
# POSIX-shell wrapper around an awk implementation of the standard
# HSL→RGB conversion, formatted as RRGGBB. Saturation and lightness are
# percentages in [0, 100]. Hue is wrapped into [0, 360).

mudrash_hsl_to_hex() {
    # mudrash_hsl_to_hex <hue> [<sat=65>] [<light=50>]
    local hue=$1
    local sat=${2:-65}
    local light=${3:-50}
    awk -v h="$hue" -v S="$sat" -v L="$light" '
    function abs(x)     { return x < 0 ? -x : x }
    function fmod(x, y) { return x - int(x/y) * y }
    BEGIN {
        H = h % 360
        if (H < 0) H = H + 360
        s = S / 100.0
        l = L / 100.0

        C  = (1 - abs(2*l - 1)) * s
        Hp = H / 60.0
        X  = C * (1 - abs(fmod(Hp, 2) - 1))

        if      (Hp < 1) { R=C; G=X; B=0 }
        else if (Hp < 2) { R=X; G=C; B=0 }
        else if (Hp < 3) { R=0; G=C; B=X }
        else if (Hp < 4) { R=0; G=X; B=C }
        else if (Hp < 5) { R=X; G=0; B=C }
        else             { R=C; G=0; B=X }

        m = l - C/2
        r = int((R + m) * 255 + 0.5)
        g = int((G + m) * 255 + 0.5)
        b = int((B + m) * 255 + 0.5)
        printf "%02x%02x%02x\n", r, g, b
    }'
}

mudrash_hex_to_rgb() {
    # mudrash_hex_to_rgb <hex6>  → prints "R G B" (decimal, space-separated).
    # Used by `mudrash status` to render a 24-bit ANSI swatch.
    #
    # NOTE: must stay POSIX — `bin/mudrash` is /bin/sh which is dash on
    # Ubuntu/Debian. The bash substring syntax ${var:start:length} silently
    # works on macOS sh (= bash --posix) but parses-errors in dash.
    local hex=$1
    local rr gg bb
    rr=${hex%????}        # strip last 4 chars → first 2 (e.g. "d2")
    gg=${hex#??}          # strip first 2 → "2d2d"
    gg=${gg%??}           # then strip last 2 → "2d"
    bb=${hex#????}        # strip first 4 → last 2 (e.g. "2d")
    printf '%d %d %d\n' "$((0x$rr))" "$((0x$gg))" "$((0x$bb))"
}

mudrash_bg_color() {
    # Subdued background for OSC 11 dark-theme tint (S=30, L=14).
    # Calibrated to be visible against dark themes without overwhelming the
    # content that renders on top.
    mudrash_hsl_to_hex "$1" 30 14
}
