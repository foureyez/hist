# Source this in your ~/.zshrc
autoload -U add-zsh-hook

zmodload zsh/datetime 2>/dev/null

cmdh_HISTORY_ID=""
_cmdh_preexec() {
    local id
    id=$(cmdh history start -- "$1")
    export cmdh_HISTORY_ID="$id"
    __cmdh_preexec_time=${EPOCHREALTIME-}
}

_cmdh_precmd() {
    local EXIT="$?" __cmdh_precmd_time=${EPOCHREALTIME-}

    [[ -z "${cmdh_HISTORY_ID:-}" ]] && return

    local duration=""
    if [[ -n $__cmdh_preexec_time && -n $__cmdh_precmd_time ]]; then
        printf -v duration %.0f $(((__cmdh_precmd_time - __cmdh_preexec_time) * 1000000000))
    fi

    (cmdh_LOG=error cmdh history end --exit $EXIT ${duration:+--duration=$duration} -- $cmdh_HISTORY_ID &) >/dev/null 2>&1
    export cmdh_HISTORY_ID=""
}

__cmdh_search_cmd() {
    local -a search_args=("$@")

    if __cmdh_tmux_popup_check; then
        __cmdh_popup_tmpdir=$(mktemp -d) || return 1
        local result_file="$__cmdh_popup_tmpdir/result"

        trap '__cmdh_tmux_popup_cleanup' EXIT HUP INT TERM

        local escaped_query escaped_args
        escaped_query=$(printf '%s' "$BUFFER" | sed "s/'/'\\\\''/g")
        escaped_args=""
        for arg in "${search_args[@]}"; do
            escaped_args+=" '$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")'"
        done

        # In the popup, cmdh goes to terminal, stderr goes to file
        local cdir popup_width popup_height
        cdir=$(pwd)
        popup_width="${cmdh_TMUX_POPUP_WIDTH:-80%}" # Keep default value anyways
        popup_height="${cmdh_TMUX_POPUP_HEIGHT:-60%}"
        tmux display-popup -d "$cdir" -w "$popup_width" -h "$popup_height" -E -E -- \
            sh -c "cmdh_SHELL=zsh cmdh_LOG=error cmdh_QUERY='$escaped_query' cmdh search $escaped_args -i 2>'$result_file'"

        if [[ -f "$result_file" ]]; then
            cat "$result_file"
        fi

        __cmdh_tmux_popup_cleanup
        trap - EXIT HUP INT TERM
    else
        cmdh_SHELL=zsh cmdh_LOG=error cmdh_QUERY=$BUFFER cmdh search "${search_args[@]}" -i 3>&1 1>&2 2>&3
    fi
}

_cmdh_search() {
    emulate -L zsh
    zle -I

    # swap stderr and stdout, so that the tui stuff works
    # TODO: not this
    local output
    # shellcheck disable=SC2048
    output=$(__cmdh_search_cmd $*)

    zle reset-prompt
    # re-enable bracketed paste
    # shellcheck disable=SC2154
    echo -n ${zle_bracketed_paste[1]} >/dev/tty

    if [[ -n $output ]]; then
        RBUFFER=""
        LBUFFER=$output

        if [[ $LBUFFER == __cmdh_accept__:* ]]
        then
            LBUFFER=${LBUFFER#__cmdh_accept__:}
            zle accept-line
        fi
    fi
}

add-zsh-hook preexec _cmdh_preexec
add-zsh-hook precmd _cmdh_precmd

zle -N cmdh-search _cmdh_search
