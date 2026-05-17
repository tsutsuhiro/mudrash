# test/helpers.bash — shared helpers for bats tests
#
# Bats runs each test in a fresh bash subshell. Tests source this file via
# `load helpers` (which resolves to `helpers.bash` next to the .bats file).

export MUDRASH_REPO_ROOT="${BATS_TEST_DIRNAME}/.."

# Path to a zsh interpreter. Tests that exercise mudrash.zsh (preexec, prompt
# integration) spawn zsh explicitly; pure-library tests source the .zsh file
# directly under bash.
ZSH_BIN="${ZSH_BIN:-zsh}"

# Run a snippet inside zsh, with the repo root cwd-friendly.
run_zsh() {
    "$ZSH_BIN" --no-rcs -c "$1"
}
