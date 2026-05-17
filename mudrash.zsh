# mudrash.zsh — zsh preexec hook for per-project agent tinting
# v0.2.0
#
# This file is sourced from your .zshrc. It registers a `preexec` hook that
# listens for invocations of commands listed in MUDRASH_AGENTS (default:
# claude, codex) and, on match, emits OSC 0 (terminal title) and OSC 11
# (terminal background) sequences.
#
# Design contract (see README.md): never touches the agent's config, context,
# input, or behavior — only ANSI/OSC escapes. The PROMPT is NOT modified.

MUDRASH_VERSION='0.2.0'

# Resolve own directory so we can find ./lib/ regardless of how we're sourced.
# %x in a prompt expansion expands to the path of the currently sourced file.
typeset -g _MUDRASH_DIR=${${(%):-%x}:A:h}

# shellcheck disable=SC1091
source "$_MUDRASH_DIR/lib/hash.zsh"
# shellcheck disable=SC1091
source "$_MUDRASH_DIR/lib/color.zsh"

# Per-shell cache so unchanged cwd skips hash + color recomputation.
typeset -g _MUDRASH_CACHED_PWD=''
typeset -g _MUDRASH_CACHED_LABEL=''
typeset -g _MUDRASH_CACHED_BG=''

# Default agent list. Override via MUDRASH_AGENTS in env.
typeset -g _MUDRASH_DEFAULT_AGENTS='claude codex'

_mudrash_refresh_cache() {
    # Updates _MUDRASH_CACHED_{PWD,LABEL,BG} when cwd has changed since the
    # last call. Mutations must happen in the *current* shell (no subshell)
    # otherwise the cache would never persist.
    if [[ "$PWD" == "$_MUDRASH_CACHED_PWD" && -n "$_MUDRASH_CACHED_BG" ]]; then
        return
    fi
    local label hue
    label=${PWD:t}
    hue=$(mudrash_hue "$label")
    _MUDRASH_CACHED_LABEL=$label
    _MUDRASH_CACHED_BG=$(mudrash_bg_color "$hue")
    _MUDRASH_CACHED_PWD=$PWD
}

_mudrash_preexec() {
    # HOT PATH. Order matters: cheapest rejection first.
    [[ -n "$MUDRASH_DISABLE" ]] && return

    # First whitespace token, then basename (handles /usr/local/bin/claude).
    local cmd=${1%% *}
    cmd=${cmd:t}

    local agents=${MUDRASH_AGENTS:-$_MUDRASH_DEFAULT_AGENTS}
    case " $agents " in
        *" $cmd "*) ;;
        *) return ;;
    esac

    # Confirmed match. Refresh cache then emit decorations.
    _mudrash_refresh_cache

    # OSC 0: set the terminal window/tab title. Most full-screen TUI agents
    # immediately overwrite this; useful at the moment of launch.
    printf '\033]0;%s ▸ %s\007' "$_MUDRASH_CACHED_LABEL" "$cmd"

    # OSC 11: set the terminal background. Survives full-screen TUI agents
    # because Claude Code and similar Ink/blessed-based TUIs do not paint
    # their own background — they render text over the terminal's default.
    # This is the primary signal: project identity that's visible
    # even while the agent owns the screen.
    printf '\033]11;#%s\007' "$_MUDRASH_CACHED_BG"
}

# --- Hook registration ----------------------------------------------------

# Always register, regardless of MUDRASH_DISABLE. The hook itself short-
# circuits on disable, so toggling the env var works without re-sourcing.
autoload -Uz add-zsh-hook 2>/dev/null
if (( ${+functions[add-zsh-hook]} )); then
    add-zsh-hook preexec _mudrash_preexec
else
    typeset -ga preexec_functions
    # Avoid duplicate registration on re-source.
    if [[ ${preexec_functions[(ie)_mudrash_preexec]} -gt ${#preexec_functions} ]]; then
        preexec_functions+=(_mudrash_preexec)
    fi
fi
