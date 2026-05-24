# Source this in your ~/.zshrc
autoload -U add-zsh-hook

zmodload zsh/datetime 2>/dev/null

hist_HISTORY_ID=""
_hist_preexec() {
    local id
    id=$(hist add start "$1")
    export hist_HISTORY_ID="$id"
    __hist_preexec_time=${EPOCHREALTIME-}
}

_hist_precmd() {
    local EXIT="$?" __hist_precmd_time=${EPOCHREALTIME-}

    [[ -z "${hist_HISTORY_ID:-}" ]] && return

    local duration=""
    if [[ -n $__hist_preexec_time && -n $__hist_precmd_time ]]; then
        printf -v duration %.0f $(((__hist_precmd_time - __hist_preexec_time) * 1000))
    fi

    (hist add end $hist_HISTORY_ID $EXIT $duration &) >/dev/null 2>&1
    export hist_HISTORY_ID=""
}

__hist_search_cmd() {
    local -a search_args=("$@")
    HIST_QUERY=$BUFFER hist search "${search_args[@]}" 
}

_hist_search() {
    emulate -L zsh
    zle -I

    local output
    output=$(__hist_search_cmd $*)

    zle reset-prompt
    # re-enable bracketed paste
    # shellcheck disable=SC2154
    echo -n ${zle_bracketed_paste[1]} >/dev/tty

    if [[ -n $output ]]; then
        RBUFFER=""
        LBUFFER=$output
    fi
}

add-zsh-hook preexec _hist_preexec
add-zsh-hook precmd _hist_precmd

zle -N hist-search _hist_search
