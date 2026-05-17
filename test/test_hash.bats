#!/usr/bin/env bats

load helpers

setup() {
    # shellcheck disable=SC1091
    source "${MUDRASH_REPO_ROOT}/lib/hash.zsh"
}

# ----- _mudrash_apply_knee -------------------------------------------------

@test "apply_knee: 0 is unchanged" {
    run _mudrash_apply_knee 0
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "apply_knee: 49 is unchanged (just below low knee)" {
    run _mudrash_apply_knee 49
    [ "$output" = "49" ]
}

@test "apply_knee: 50 shifts +30 → 80" {
    run _mudrash_apply_knee 50
    [ "$output" = "80" ]
}

@test "apply_knee: 60 shifts +30 → 90" {
    run _mudrash_apply_knee 60
    [ "$output" = "90" ]
}

@test "apply_knee: 70 shifts +30 → 100" {
    run _mudrash_apply_knee 70
    [ "$output" = "100" ]
}

@test "apply_knee: 71 is unchanged (just above low knee)" {
    run _mudrash_apply_knee 71
    [ "$output" = "71" ]
}

@test "apply_knee: 269 is unchanged (just below high knee)" {
    run _mudrash_apply_knee 269
    [ "$output" = "269" ]
}

@test "apply_knee: 270 shifts +25 → 295" {
    run _mudrash_apply_knee 270
    [ "$output" = "295" ]
}

@test "apply_knee: 280 shifts +25 → 305" {
    run _mudrash_apply_knee 280
    [ "$output" = "305" ]
}

@test "apply_knee: 290 shifts +25 → 315" {
    run _mudrash_apply_knee 290
    [ "$output" = "315" ]
}

@test "apply_knee: 291 is unchanged (just above high knee)" {
    run _mudrash_apply_knee 291
    [ "$output" = "291" ]
}

# ----- mudrash_hue ---------------------------------------------------------

@test "mudrash_hue is deterministic for same input" {
    a=$(mudrash_hue "myapp")
    b=$(mudrash_hue "myapp")
    [ "$a" = "$b" ]
}

@test "mudrash_hue stays in [0, 360)" {
    for key in alpha beta gamma delta epsilon zeta eta theta iota kappa; do
        h=$(mudrash_hue "$key")
        [ "$h" -ge 0 ]
        [ "$h" -lt 360 ]
    done
}

@test "mudrash_hue never returns a value in the low knee zone" {
    for key in proj1 proj2 myapp test foo bar baz qux abc xyz alpha beta gamma; do
        h=$(mudrash_hue "$key")
        if [ "$h" -ge 50 ] && [ "$h" -le 70 ]; then
            printf 'key=%s hue=%s landed in low knee\n' "$key" "$h" >&2
            return 1
        fi
    done
}

@test "mudrash_hue never returns a value in the high knee zone" {
    for key in proj1 proj2 myapp test foo bar baz qux abc xyz alpha beta gamma; do
        h=$(mudrash_hue "$key")
        if [ "$h" -ge 270 ] && [ "$h" -le 290 ]; then
            printf 'key=%s hue=%s landed in high knee\n' "$key" "$h" >&2
            return 1
        fi
    done
}

@test "mudrash_hue differs for different keys (smoke)" {
    a=$(mudrash_hue "alpha")
    b=$(mudrash_hue "omega")
    [ "$a" != "$b" ]
}

@test "_mudrash_hue_raw('A') = 29 (sha1 prefix 6dcd = 28109, mod 360)" {
    # sha1("A") = 6dcd4ce23d88e2ee9568ba546c007c63d9131c1b
    # 0x6dcd = 28109; 28109 % 360 = 29
    run _mudrash_hue_raw "A"
    [ "$output" = "29" ]
}
