#!/usr/bin/env bats

load helpers

setup() {
    SANDBOX_HOME=$(mktemp -d -t mudrash-install-XXXXXX)
    export HOME="$SANDBOX_HOME"
    export SHELL=/bin/zsh
    # Make sure XDG path doesn't accidentally point at the user's real one.
    unset XDG_DATA_HOME
}

teardown() {
    rm -rf "$SANDBOX_HOME"
}

@test "install.sh: rejects non-zsh \$SHELL" {
    SHELL=/bin/bash run "$MUDRASH_REPO_ROOT/install.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"zsh only"* ]]
}

@test "install.sh: copies mudrash.zsh, lib/, bin/mudrash, install.sh into ~/.local/share/mudrash" {
    run "$MUDRASH_REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$HOME/.local/share/mudrash/mudrash.zsh" ]
    [ -f "$HOME/.local/share/mudrash/lib/hash.zsh" ]
    [ -f "$HOME/.local/share/mudrash/lib/color.zsh" ]
    [ -x "$HOME/.local/share/mudrash/bin/mudrash" ]
    [ -x "$HOME/.local/share/mudrash/install.sh" ]
}

@test "install.sh: adds marker block with source line to ~/.zshrc" {
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    [ -f "$HOME/.zshrc" ]
    grep -qF '# >>> mudrash >>>' "$HOME/.zshrc"
    grep -qF '# <<< mudrash <<<' "$HOME/.zshrc"
    grep -q 'source.*mudrash.zsh' "$HOME/.zshrc"
    grep -q 'export PATH=.*mudrash/bin' "$HOME/.zshrc"
}

@test "install.sh: prints next-step message" {
    run "$MUDRASH_REPO_ROOT/install.sh"
    [[ "$output" == *"source ~/.zshrc"* ]]
}

@test "install.sh: idempotent — running twice keeps exactly one block" {
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    count_open=$(grep -cF '# >>> mudrash >>>' "$HOME/.zshrc")
    count_close=$(grep -cF '# <<< mudrash <<<' "$HOME/.zshrc")
    [ "$count_open" -eq 1 ]
    [ "$count_close" -eq 1 ]
}

@test "install.sh: preserves pre-existing .zshrc content" {
    {
        echo '# my settings'
        echo 'alias ll="ls -la"'
        echo 'export EDITOR=vim'
    } > "$HOME/.zshrc"
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    grep -qF '# my settings' "$HOME/.zshrc"
    grep -qF 'alias ll="ls -la"' "$HOME/.zshrc"
    grep -qF 'export EDITOR=vim' "$HOME/.zshrc"
}

@test "install.sh: re-install with new content replaces previous block contents" {
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    first=$(grep -cF '# >>> mudrash >>>' "$HOME/.zshrc")
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    second=$(grep -cF '# >>> mudrash >>>' "$HOME/.zshrc")
    [ "$first" -eq 1 ]
    [ "$second" -eq 1 ]
}

@test "mudrash uninstall: removes install dir and marker block" {
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    [ -d "$HOME/.local/share/mudrash" ]
    "$HOME/.local/share/mudrash/bin/mudrash" uninstall >/dev/null
    [ ! -d "$HOME/.local/share/mudrash" ]
    ! grep -qF '# >>> mudrash >>>' "$HOME/.zshrc"
    ! grep -qF '# <<< mudrash <<<' "$HOME/.zshrc"
}

@test "mudrash uninstall: preserves user's other .zshrc content" {
    {
        echo '# user settings'
        echo 'alias ll="ls -la"'
    } > "$HOME/.zshrc"
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    "$HOME/.local/share/mudrash/bin/mudrash" uninstall >/dev/null
    grep -qF '# user settings' "$HOME/.zshrc"
    grep -qF 'alias ll="ls -la"' "$HOME/.zshrc"
}

@test "installed mudrash.zsh sources cleanly under zsh and registers hook" {
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    run zsh --no-rcs -c 'source $HOME/.local/share/mudrash/mudrash.zsh; print -l $preexec_functions'
    [ "$status" -eq 0 ]
    [[ "$output" == *"_mudrash_preexec"* ]]
}

@test "mudrash uninstall: emits OSC 111 (terminal bg reset) to stdout" {
    "$MUDRASH_REPO_ROOT/install.sh" >/dev/null
    output=$("$HOME/.local/share/mudrash/bin/mudrash" uninstall)
    # OSC 111 sequence: ESC ] 111 BEL
    [[ "$output" == *$'\033]111\a'* ]]
}
