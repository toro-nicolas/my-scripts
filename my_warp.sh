#!/bin/bash
if [ -n "$1" ]; then
    DIR="$1"
else
    DIR="$(pwd)"
fi

if [[ ! -d "$DIR" ]]; then
    echo "Error: Directory '$DIR' does not exist." >&2
    exit 1
fi

cd "$DIR" || exit
warp-terminal &
