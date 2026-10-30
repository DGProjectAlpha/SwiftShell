#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck source=common.sh
. "$HERE/common.sh"

swiftshell_need_home
swiftshell_require_install
swiftshell_desktop_writable

state=$(swiftshell_state_dir)
swiftshell_assert_managed_path "$state"
swiftshell_ensure_quickshell_link

mkdir -p "$state"
cat >"$state/active" <<EOF
product=swiftshell
app=$(swiftshell_app_dir)
EOF
swiftshell_write_desktop
swiftshell_say "activated. Existing shell files were not replaced."
swiftshell_say "this does not change Hyprland startup, shortcuts, or services."
swiftshell_say "start now with: swiftshell start"
swiftshell_say "to start it with the session, add that command yourself after you have seen it run."
