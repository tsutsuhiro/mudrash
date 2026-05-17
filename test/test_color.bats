#!/usr/bin/env bats

load helpers

setup() {
    # shellcheck disable=SC1091
    source "${MUDRASH_REPO_ROOT}/lib/color.zsh"
}

@test "hsl_to_hex: red @ hue=0 S=65 L=50 → d22d2d" {
    run mudrash_hsl_to_hex 0 65 50
    [ "$status" -eq 0 ]
    [ "$output" = "d22d2d" ]
}

@test "hsl_to_hex: green @ hue=120 S=65 L=50 → 2dd22d" {
    run mudrash_hsl_to_hex 120 65 50
    [ "$output" = "2dd22d" ]
}

@test "hsl_to_hex: blue @ hue=240 S=65 L=50 → 2d2dd2" {
    run mudrash_hsl_to_hex 240 65 50
    [ "$output" = "2d2dd2" ]
}

@test "hsl_to_hex: defaults S=65 L=50 when omitted" {
    run mudrash_hsl_to_hex 0
    [ "$output" = "d22d2d" ]
}

@test "hsl_to_hex: emits exactly 6 lowercase hex chars" {
    run mudrash_hsl_to_hex 90
    [ "${#output}" -eq 6 ]
    [[ "$output" =~ ^[0-9a-f]{6}$ ]]
}

@test "hsl_to_hex: hue=360 wraps to hue=0" {
    a=$(mudrash_hsl_to_hex 0)
    b=$(mudrash_hsl_to_hex 360)
    [ "$a" = "$b" ]
}

@test "hsl_to_hex: white at L=100" {
    run mudrash_hsl_to_hex 0 65 100
    [ "$output" = "ffffff" ]
}

@test "hsl_to_hex: black at L=0" {
    run mudrash_hsl_to_hex 0 65 0
    [ "$output" = "000000" ]
}

@test "hsl_to_hex: medium gray at S=0 L=50 → 808080" {
    run mudrash_hsl_to_hex 0 0 50
    [ "$output" = "808080" ]
}

# ----- bg color (subdued dark-theme background, OSC 11 input) ---------------

@test "bg_color: hue=0 → 2e1919 (dark red, S=30, L=14)" {
    run mudrash_bg_color 0
    [ "$status" -eq 0 ]
    [ "$output" = "2e1919" ]
}

@test "bg_color: hue=120 → 192e19 (dark green)" {
    run mudrash_bg_color 120
    [ "$output" = "192e19" ]
}

@test "bg_color: hue=240 → 19192e (dark blue)" {
    run mudrash_bg_color 240
    [ "$output" = "19192e" ]
}

@test "bg_color: emits exactly 6 lowercase hex chars" {
    run mudrash_bg_color 90
    [ "${#output}" -eq 6 ]
    [[ "$output" =~ ^[0-9a-f]{6}$ ]]
}

@test "hex_to_rgb: d22d2d → 210 45 45" {
    run mudrash_hex_to_rgb d22d2d
    [ "$output" = "210 45 45" ]
}

@test "hex_to_rgb: 000000 → 0 0 0" {
    run mudrash_hex_to_rgb 000000
    [ "$output" = "0 0 0" ]
}

@test "hex_to_rgb: ffffff → 255 255 255" {
    run mudrash_hex_to_rgb ffffff
    [ "$output" = "255 255 255" ]
}

@test "hex_to_rgb works under /bin/sh (POSIX, not just bash)" {
    # Regression: lib/color.zsh must be POSIX-shell compatible because
    # bin/mudrash is /bin/sh (dash on Ubuntu). Bash-only substring
    # syntax ${var:start:length} would silently work under bash-as-sh
    # on macOS but fail in dash. Run under sh -c explicitly.
    run sh -c '. '"${MUDRASH_REPO_ROOT}"'/lib/color.zsh && mudrash_hex_to_rgb d22d2d'
    [ "$status" -eq 0 ]
    [ "$output" = "210 45 45" ]
}
