#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
state_dir="${TMPDIR:-/tmp}/shining-soul-godot-state"
mkdir -p "$state_dir/data" "$state_dir/config" "$state_dir/cache"
export XDG_DATA_HOME="$state_dir/data"
export XDG_CONFIG_HOME="$state_dir/config"
export XDG_CACHE_HOME="$state_dir/cache"
exec godot --path "$project_dir" "$@"
