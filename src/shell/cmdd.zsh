# Source this in your ~/.zshrc
autoload -U add-zsh-hook

zmodload zsh/datetime 2>/dev/null

histr_HISTORY_ID=""
_histr_preexec() {
    local id
    id=$(histr history start -- "$1")
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

    (histr_LOG=error histr history end --exit $EXIT ${duration:+--duration=$duration} -- $histr_HISTORY_ID &) >/dev/null 2>&1
    export histr_HISTORY_ID=""
}

__histr_search_cmd() {
    local -a search_args=("$@")

    if __histr_tmux_popup_check; then
        __histr_popup_tmpdir=$(mktemp -d) || return 1
        local result_file="$__histr_popup_tmpdir/result"

        trap '__histr_tmux_popup_cleanup' EXIT HUP INT TERM

        local escaped_query escaped_args
        escaped_query=$(printf '%s' "$BUFFER" | sed "s/'/'\\\\''/g")
        escaped_args=""
        for arg in "${search_args[@]}"; do
            escaped_args+=" '$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")'"
        done

        # In the popup, histr goes to terminal, stderr goes to file
        local cdir popup_width popup_height
        cdir=$(pwd)
        popup_width="${histr_TMUX_POPUP_WIDTH:-80%}" # Keep default value anyways
        popup_height="${histr_TMUX_POPUP_HEIGHT:-60%}"
        tmux display-popup -d "$cdir" -w "$popup_width" -h "$popup_height" -E -E -- \
            sh -c "histr_SHELL=zsh histr_LOG=error histr_QUERY='$escaped_query' histr search $escaped_args -i 2>'$result_file'"

        if [[ -f "$result_file" ]]; then
            cat "$result_file"
        fi

        __histr_tmux_popup_cleanup
        trap - EXIT HUP INT TERM
    else
        histr_SHELL=zsh histr_LOG=error histr_QUERY=$BUFFER histr search "${search_args[@]}" -i 3>&1 1>&2 2>&3
    fi
}

_histr_search() {
    emulate -L zsh
    zle -I

    # swap stderr and stdout, so that the tui stuff works
    # TODO: not this
    local output
    # shellcheck disable=SC2048
    output=$(__histr_search_cmd $*)

    zle reset-prompt
    # re-enable bracketed paste
    # shellcheck disable=SC2154
    echo -n ${zle_bracketed_paste[1]} >/dev/tty

    if [[ -n $output ]]; then
        RBUFFER=""
        LBUFFER=$output

        if [[ $LBUFFER == __histr_accept__:* ]]
        then
            LBUFFER=${LBUFFER#__histr_accept__:}
            zle accept-line
        fi
    fi
}

add-zsh-hook preexec _histr_preexec
add-zsh-hook precmd _histr_precmd

zle -N histr-search _histr_search
