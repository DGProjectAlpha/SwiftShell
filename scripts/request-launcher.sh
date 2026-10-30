#!/bin/sh
# Ask a running SwiftShell to open the launcher. Does not edit Hyprland.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
# shellcheck source=lib/common.sh
. "$ROOT/scripts/lib/common.sh"
swiftshell_request_launcher
