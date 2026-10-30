#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck source=common.sh
. "$HERE/common.sh"

swiftshell_need_home

data=$(swiftshell_data_dir)
swiftshell_assert_managed_path "$data"

if [ -L "$data" ]; then
    swiftshell_die "refusing to remove an install path that is a symlink."
fi

if [ -d "$data" ] && ! swiftshell_dir_empty "$data" && ! swiftshell_looks_like_ours "$data"; then
    swiftshell_die "refusing to remove a directory that is not a SwiftShell install."
fi

if swiftshell_looks_like_ours "$data"; then
    swiftshell_stop_running || true
fi

swiftshell_remove_quickshell_link
swiftshell_remove_desktop
swiftshell_remove_wrapper

state=$(swiftshell_state_dir)
if [ -f "$state/active" ]; then
    swiftshell_assert_managed_path "$state/active"
    rm -f "$state/active"
fi
rmdir "$state" 2>/dev/null || true

if [ -d "$data/app" ]; then
    swiftshell_assert_managed_path "$data/app"
    rm -rf "$data/app"
fi
if [ -d "$data/lib" ]; then
    swiftshell_assert_managed_path "$data/lib"
    rm -rf "$data/lib"
fi
rm -f "$data/manifest"
rmdir "$data" 2>/dev/null || swiftshell_warn "left the data directory because it still contains other files."

if [ "${SWIFTSHELL_PURGE_SETTINGS:-0}" = 1 ]; then
    config=$(swiftshell_config_dir)
    swiftshell_assert_managed_path "$config"
    if [ -L "$config" ]; then
        swiftshell_die "refusing to remove a settings path that is a symlink."
    fi
    if [ -d "$config" ]; then
        rm -rf "$config"
        swiftshell_say "removed user settings."
    fi
else
    swiftshell_say "user settings were kept."
fi

swiftshell_say "uninstalled."
