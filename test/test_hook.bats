#!/usr/bin/env bats

load helpers

# All hook tests spawn a fresh zsh subshell so we exercise the actual
# preexec function path that runs in production.

# ----- OSC 0 (terminal title) ----------------------------------------------

@test "preexec emits OSC 0 title for claude" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "claude foo"
    ')
    [[ "$output" == *$'\033]0;'*' ▸ claude'$'\a'* ]]
}

@test "preexec emits OSC 0 title for codex" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "codex"
    ')
    [[ "$output" == *' ▸ codex'$'\a'* ]]
}

# ----- OSC 11 (terminal background) ----------------------------------------

@test "preexec emits OSC 11 with the bg hex" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "claude foo"
    ')
    # OSC 11 sequence: ESC ] 11 ; #RRGGBB BEL
    [[ "$output" == *$'\033]11;#'*$'\a'* ]]
}

@test "preexec OSC 11 bg matches mudrash_bg_color of current cwd" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "claude" >/dev/null
        hue=$(mudrash_hue "${PWD:t}")
        expected=$(mudrash_bg_color "$hue")
        printf "%s=%s" "$_MUDRASH_CACHED_BG" "$expected"
    ')
    actual=${output%%=*}
    expected=${output##*=}
    [ "$actual" = "$expected" ]
}

@test "OSC 11 is deterministic for the same cwd across sessions" {
    tmpdir=$(mktemp -d -t mudrash-osc11-XXXXXX)
    grab='cd "$1"; source "$MUDRASH_REPO_ROOT/mudrash.zsh"; _mudrash_preexec "claude" | tr -d "\n"'
    out1=$(zsh --no-rcs -c "$grab" -- "$tmpdir")
    out2=$(zsh --no-rcs -c "$grab" -- "$tmpdir")
    rmdir "$tmpdir"
    [ -n "$out1" ]
    [ "$out1" = "$out2" ]
}

@test "OSC 11 differs for different cwds" {
    out_a=$(zsh --no-rcs -c '
        cd $(mktemp -d -t mudrash-a-XXXXXX)
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "claude"
        rmdir "$PWD" 2>/dev/null
    ')
    out_b=$(zsh --no-rcs -c '
        cd $(mktemp -d -t mudrash-b-XXXXXX)
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "claude"
        rmdir "$PWD" 2>/dev/null
    ')
    [ "$out_a" != "$out_b" ]
}

# ----- Gating (DISABLE + agent match) --------------------------------------

@test "preexec emits no OSC sequences when MUDRASH_DISABLE=1" {
    output=$(zsh --no-rcs -c '
        export MUDRASH_DISABLE=1
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "claude foo"
        printf "EOF"
    ')
    [ "$output" = "EOF" ]
}

@test "preexec emits nothing for non-agent commands (ls)" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "ls -la"
        printf "EOF"
    ')
    [ "$output" = "EOF" ]
}

@test "preexec emits nothing for multi-word non-agent (git status)" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "git status"
        printf "EOF"
    ')
    [ "$output" = "EOF" ]
}

# ----- Command parsing -----------------------------------------------------

@test "preexec handles absolute-path invocation: /usr/local/bin/claude" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "/usr/local/bin/claude foo"
    ')
    # Should fire (OSC sequences emitted) because basename(cmd) == "claude"
    [[ "$output" == *$'\033]11;#'* ]]
}

@test "preexec honors MUDRASH_AGENTS (adds 'aider')" {
    output=$(zsh --no-rcs -c '
        export MUDRASH_AGENTS="claude codex aider"
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "aider chat"
    ')
    [[ "$output" == *$'\033]11;#'* ]]
}

# ----- Hook registration ---------------------------------------------------

@test "preexec is registered in preexec_functions" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        print -l $preexec_functions
    ')
    [[ "$output" == *"_mudrash_preexec"* ]]
}

# ----- Cache ---------------------------------------------------------------

@test "cwd cache: second call with same cwd reuses cached bg" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "claude" >/dev/null
        # Mutate the cache so we can prove the second call did not recompute.
        _MUDRASH_CACHED_BG="deadbe"
        _mudrash_preexec "claude"
    ')
    # The second OSC 11 emission should carry the mutated cache value.
    [[ "$output" == *$'\033]11;#deadbe'* ]]
}

# ----- PROMPT is NOT touched (regression — never set prompt prefix) ---

@test "sourcing mudrash.zsh does not modify PROMPT" {
    output=$(zsh --no-rcs -c '
        PROMPT="custom-prompt %~ $ "
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        printf "%s" "$PROMPT"
    ')
    [ "$output" = "custom-prompt %~ $ " ]
}

@test "preexec does not set MUDRASH_PROMPT_PREFIX" {
    output=$(zsh --no-rcs -c '
        source "$MUDRASH_REPO_ROOT/mudrash.zsh"
        _mudrash_preexec "claude" >/dev/null
        printf "<%s>" "${MUDRASH_PROMPT_PREFIX:-UNSET}"
    ')
    [ "$output" = "<UNSET>" ]
}
