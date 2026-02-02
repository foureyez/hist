# Source this in your ~/.zshrc
autoload -U add-zsh-hook

zmodload zsh/datetime 2>/dev/null

histr_HISTORY_ID=""
_histr_preexec() {
    local id
    id=$(histr add start "$1")
    export histr_HISTORY_ID="$id"
    __histr_preexec_time=${EPOCHREALTIME-}
}

_histr_precmd() {
    local EXIT="$?" __histr_precmd_time=${EPOCHREALTIME-}

    [[ -z "${histr_HISTORY_ID:-}" ]] && return

    local duration=""
    if [[ -n $__histr_preexec_time && -n $__histr_precmd_time ]]; then
        printf -v duration %.0f $(((__histr_precmd_time - __histr_preexec_time) * 1000000000))
    fi

    (histr add end $histr_HISTORY_ID $EXIT $duration &) >/dev/null 2>&1
    export histr_HISTORY_ID=""
}

__histr_search_cmd() {
    local -a search_args=("$@")
    HISTR_QUERY=$BUFFER histr search "${search_args[@]}" 
}

_histr_search() {
    emulate -L zsh
    zle -I

    local output
    output=$(__histr_search_cmd $*)

    zle reset-prompt
    # re-enable bracketed paste
    # shellcheck disable=SC2154
    echo -n ${zle_bracketed_paste[1]} >/dev/tty

    if [[ -n $output ]]; then
        RBUFFER=""
        LBUFFER=$output
    fi
}

add-zsh-hook preexec _histr_preexec
add-zsh-hook precmd _histr_precmd

zle -N histr-search _histr_search
