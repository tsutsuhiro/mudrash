#!/usr/bin/env bats

load helpers

MUDRASH_BIN="${MUDRASH_REPO_ROOT}/bin/mudrash"

@test "mudrash version prints exactly 0.2.0" {
    run "$MUDRASH_BIN" version
    [ "$status" -eq 0 ]
    [ "$output" = "0.2.0" ]
}

@test "mudrash --version is an alias for version" {
    run "$MUDRASH_BIN" --version
    [ "$status" -eq 0 ]
    [ "$output" = "0.2.0" ]
}

@test "mudrash --help shows usage" {
    run "$MUDRASH_BIN" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
    [[ "$output" == *"install"* ]]
    [[ "$output" == *"uninstall"* ]]
    [[ "$output" == *"status"* ]]
}

@test "mudrash (no args) shows usage" {
    run "$MUDRASH_BIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
}

@test "mudrash status shows install location, env, and current color" {
    run "$MUDRASH_BIN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Install location:"* ]]
    [[ "$output" == *"MUDRASH_MODE"* ]]
    [[ "$output" == *"MUDRASH_AGENTS"* ]]
    [[ "$output" == *"MUDRASH_DISABLE"* ]]
    [[ "$output" =~ \#[0-9a-f]{6} ]]
}

@test "mudrash status reports current cwd's basename as label" {
    tmpdir=$(mktemp -d -t mudrash-status-XXXXXX)
    cd "$tmpdir"
    run "$MUDRASH_BIN" status
    label_line=$(printf '%s\n' "$output" | grep -E '^  label')
    [[ "$label_line" == *"$(basename "$tmpdir")"* ]]
    rmdir "$tmpdir"
}

@test "mudrash status shows bg color" {
    run "$MUDRASH_BIN" status
    [ "$status" -eq 0 ]
    # The bg line must appear with a 6-digit hex code.
    bg_line=$(printf '%s\n' "$output" | grep -E '^  bg')
    [[ "$bg_line" =~ \#[0-9a-f]{6} ]]
}

@test "mudrash unknown-cmd exits non-zero" {
    run "$MUDRASH_BIN" not-a-real-command
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown command"* ]]
}
