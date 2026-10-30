#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
export SWIFTSHELL_ROOT="$ROOT"

# shellcheck source=lib/common.sh
. "$ROOT/scripts/lib/common.sh"
# shellcheck source=lib/deps.sh
. "$ROOT/scripts/lib/deps.sh"

SWIFTSHELL_INSTALL_DEPS=0
SWIFTSHELL_ASSUME_YES=0
SWIFTSHELL_STRICT=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [--install-deps] [--yes] [--strict]

Copy SwiftShell into the user data directory and install a launcher command.
This does not start the shell, replace another Quickshell config, or edit
Hyprland startup, shortcuts, or services.

  --install-deps   On Arch-based systems, offer to install missing packages.
  --yes            Answer yes to the package prompt. Does not overwrite configs.
  --strict         Stop if Quickshell is missing, too old, or unrecognized.

Run swiftshell activate after installation to register the launcher.
User settings stay in the XDG config directory and are not replaced.
EOF
}

while [ "$#" -gt 0 ]; do
    case $1 in
        --install-deps) SWIFTSHELL_INSTALL_DEPS=1 ;;
        --yes) SWIFTSHELL_ASSUME_YES=1 ;;
        --strict) SWIFTSHELL_STRICT=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            swiftshell_die "unknown argument: $1"
            ;;
    esac
    shift
done

export SWIFTSHELL_INSTALL_DEPS SWIFTSHELL_ASSUME_YES

swiftshell_need_home

if [ ! -f "$ROOT/shell/shell.qml" ]; then
    swiftshell_die "missing shell/shell.qml in this checkout."
fi

data=$(swiftshell_data_dir)
swiftshell_assert_managed_path "$data"
bin=$(swiftshell_bin_path)

if [ -L "$data" ]; then
    swiftshell_die "refusing to install through a symlink."
fi
if [ -d "$data" ] && ! swiftshell_dir_empty "$data" && ! swiftshell_looks_like_ours "$data"; then
    swiftshell_die "refusing to overwrite a directory that is not a SwiftShell install."
fi
if [ -e "$bin" ] && ! swiftshell_file_marked "$bin"; then
    swiftshell_die "refusing to overwrite an existing command at the launcher path."
fi

if ! swiftshell_install_missing_deps; then
    if [ "$SWIFTSHELL_STRICT" = 1 ]; then
        exit 2
    fi
    swiftshell_warn "package installation did not finish. Continuing with the file install."
fi

if ! swiftshell_report_dependencies; then
    if [ "$SWIFTSHELL_STRICT" = 1 ]; then
        swiftshell_warn "strict check failed. No files were changed."
        exit 2
    fi
    swiftshell_warn "dependency check reported a problem. Continuing because --strict was not set."
fi

mkdir -p "$data"
swiftshell_replace_tree "$ROOT/shell" "$data/app"

lib_stage=$(mktemp -d)
cp "$ROOT/scripts/lib/common.sh" "$lib_stage/common.sh"
cp "$ROOT/scripts/lib/deps.sh" "$lib_stage/deps.sh"
cp "$ROOT/scripts/lib/activate.sh" "$lib_stage/activate.sh"
cp "$ROOT/scripts/lib/deactivate.sh" "$lib_stage/deactivate.sh"
cp "$ROOT/scripts/lib/uninstall.sh" "$lib_stage/uninstall.sh"
cp "$ROOT/scripts/swiftshell" "$lib_stage/swiftshell"
chmod +x "$lib_stage/activate.sh" "$lib_stage/deactivate.sh" "$lib_stage/uninstall.sh" "$lib_stage/swiftshell"
swiftshell_replace_tree "$lib_stage" "$data/lib"
case $lib_stage in
    /tmp/*|"${TMPDIR:-/tmp}"/*) rm -rf "$lib_stage" ;;
    *) swiftshell_die "refusing to remove an unexpected temporary directory." ;;
esac

swiftshell_write_manifest "$data"
swiftshell_install_wrapper
swiftshell_seed_settings "$data/app"

swiftshell_say "installed."
swiftshell_say "launcher: $bin"
swiftshell_say "settings: $(swiftshell_config_dir)/settings.json"
swiftshell_say "next: swiftshell check"
swiftshell_say "next: swiftshell activate"
swiftshell_say "next: swiftshell start"
if ! printf '%s' ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
    swiftshell_warn "~/.local/bin is not on PATH. The shell rc files were not changed."
fi
