#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck source=common.sh
. "$HERE/common.sh"

swiftshell_need_home

if swiftshell_is_our_install "$(swiftshell_data_dir)"; then
    swiftshell_stop_running || true
fi

swiftshell_remove_quickshell_link
swiftshell_remove_desktop

state=$(swiftshell_state_dir)
if [ -f "$state/active" ]; then
    swiftshell_assert_managed_path "$state/active"
    rm -f "$state/active"
fi
rmdir "$state" 2>/dev/null || true

swiftshell_say "deactivated. Settings and the installed copy were kept."
