#!/usr/bin/env bash
STATE_FILE="$HOME/.cache/.hyprsunset_state"
TEMP=4500

if pgrep -x hyprsunset >/dev/null 2>&1; then
    state="on"
elif [[ -f "$STATE_FILE" ]]; then
    state=$(cat "$STATE_FILE")
else
    state="off"
fi

if [[ "$state" == "on" ]]; then
    printf '{"text":"🌇","class":"on","tooltip":"Night light on @ %dK"}\n' "$TEMP"
else
    printf '{"text":"☀","class":"off","tooltip":"Night light off"}\n'
fi
