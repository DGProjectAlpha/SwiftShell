# Shared path and safety helpers. This file only defines functions.

swiftshell_say() {
    printf 'SwiftShell: %s\n' "$*"
}

swiftshell_warn() {
    printf 'SwiftShell: %s\n' "$*" >&2
}

swiftshell_die() {
    swiftshell_warn "$@"
    exit 1
}

swiftshell_need_home() {
    if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]; then
        swiftshell_die "HOME must be a normal user directory."
    fi
}

swiftshell_data_home() {
    if [ -n "${XDG_DATA_HOME:-}" ]; then
        printf '%s\n' "$XDG_DATA_HOME"
    else
        printf '%s\n' "$HOME/.local/share"
    fi
}

swiftshell_config_home() {
    if [ -n "${XDG_CONFIG_HOME:-}" ]; then
        printf '%s\n' "$XDG_CONFIG_HOME"
    else
        printf '%s\n' "$HOME/.config"
    fi
}

swiftshell_state_home() {
    if [ -n "${XDG_STATE_HOME:-}" ]; then
        printf '%s\n' "$XDG_STATE_HOME"
    else
        printf '%s\n' "$HOME/.local/state"
    fi
}

swiftshell_data_dir() {
    printf '%s\n' "$(swiftshell_data_home)/swiftshell"
}

swiftshell_app_dir() {
    printf '%s\n' "$(swiftshell_data_dir)/app"
}

swiftshell_lib_dir() {
    printf '%s\n' "$(swiftshell_data_dir)/lib"
}

swiftshell_config_dir() {
    printf '%s\n' "$(swiftshell_config_home)/swiftshell"
}

swiftshell_state_dir() {
    printf '%s\n' "$(swiftshell_state_home)/swiftshell"
}

swiftshell_request_launcher() {
    swiftshell_need_home
    state=$(swiftshell_state_dir)
    mkdir -p "$state"
    token=$(date +%s).$$
    tmp=$(mktemp "$state/launcher.request.XXXXXX")
    printf '{\n  "text": "%s"\n}\n' "$token" >"$tmp"
    mv "$tmp" "$state/launcher.request"
    swiftshell_say "launcher requested."
}

swiftshell_bin_path() {
    printf '%s\n' "$HOME/.local/bin/swiftshell"
}

swiftshell_desktop_path() {
    printf '%s\n' "$(swiftshell_data_home)/applications/swiftshell.desktop"
}

swiftshell_quickshell_link() {
    printf '%s\n' "$(swiftshell_config_home)/quickshell/swiftshell"
}

swiftshell_assert_managed_path() {
    path=$1
    case $path in
        ""|/|/.|..|../*|*/..|*/../*)
            swiftshell_die "refusing unsafe path."
            ;;
    esac
    case $path in
        */swiftshell|*/swiftshell/*) ;;
        *)
            swiftshell_die "refusing to modify a path outside the swiftshell directory."
            ;;
    esac
}

swiftshell_manifest_product() {
    manifest=$1/manifest
    if [ ! -f "$manifest" ]; then
        return 1
    fi
    sed -n 's/^product=//p' "$manifest" | head -n 1
}

swiftshell_is_our_install() {
    product=$(swiftshell_manifest_product "$1" || true)
    [ "$product" = "swiftshell" ]
}

swiftshell_looks_like_ours() {
    if swiftshell_is_our_install "$1"; then
        return 0
    fi
    if [ -f "$1/app/shell.qml" ] && grep -q 'ShellId swiftshell' "$1/app/shell.qml"; then
        return 0
    fi
    return 1
}

swiftshell_file_marked() {
    if [ ! -f "$1" ]; then
        return 1
    fi
    grep -q 'swiftshell-managed-launcher' "$1"
}

swiftshell_dir_empty() {
    if [ ! -d "$1" ]; then
        return 1
    fi
    if [ -n "$(ls -A "$1" 2>/dev/null)" ]; then
        return 1
    fi
    return 0
}

swiftshell_qs_bin() {
    if command -v qs >/dev/null 2>&1; then
        command -v qs
        return 0
    fi
    if command -v quickshell >/dev/null 2>&1; then
        command -v quickshell
        return 0
    fi
    return 1
}

swiftshell_seed_settings() {
    app=$1
    config=$(swiftshell_config_dir)
    swiftshell_assert_managed_path "$config"
    mkdir -p "$config"
    if [ ! -e "$config/settings.json" ]; then
        cp "$app/config/defaults.json" "$config/settings.json"
        swiftshell_say "created default settings."
    fi
}

swiftshell_write_manifest() {
    dest=$1
    swiftshell_assert_managed_path "$dest"
    commit=unknown
    if [ -n "${SWIFTSHELL_ROOT:-}" ] && command -v git >/dev/null 2>&1; then
        if git -C "$SWIFTSHELL_ROOT" rev-parse HEAD >/dev/null 2>&1; then
            commit=$(git -C "$SWIFTSHELL_ROOT" rev-parse HEAD)
        fi
    fi
    stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    tmp=$(mktemp "$dest/manifest.XXXXXX")
    cat >"$tmp" <<EOF
product=swiftshell
format=1
git_commit=$commit
installed_at=$stamp
EOF
    mv "$tmp" "$dest/manifest"
}

swiftshell_replace_tree() {
    src=$1
    dest=$2
    swiftshell_assert_managed_path "$dest"
    parent=$(dirname "$dest")
    mkdir -p "$parent"
    stage=$(mktemp -d "$parent/.stage.XXXXXX")
    cp -a "$src"/. "$stage"/
    prev=""
    if [ -d "$dest" ]; then
        prev=$(mktemp -d "$parent/.prev.XXXXXX")
        rm -rf "$prev"
        mv "$dest" "$prev"
    fi
    if ! mv "$stage" "$dest"; then
        if [ -n "$prev" ] && [ -d "$prev" ]; then
            mv "$prev" "$dest"
        fi
        swiftshell_die "could not replace the installed tree."
    fi
    if [ -n "$prev" ]; then
        case $prev in
            */.prev.*) rm -rf "$prev" ;;
            *) swiftshell_die "refusing to remove an unexpected temporary directory." ;;
        esac
    fi
}

swiftshell_install_wrapper() {
    bin=$(swiftshell_bin_path)
    lib=$(swiftshell_lib_dir)
    mkdir -p "$(dirname "$bin")"
    if [ -e "$bin" ] && [ ! -L "$bin" ] && ! swiftshell_file_marked "$bin"; then
        swiftshell_die "refusing to overwrite an existing command at the launcher path."
    fi
    if [ -L "$bin" ]; then
        swiftshell_die "refusing to overwrite a symlink at the launcher path."
    fi
    tmp=$(mktemp "$(dirname "$bin")/.swiftshell.XXXXXX")
    cat >"$tmp" <<EOF
#!/bin/sh
# swiftshell-managed-launcher
set -eu
DATA="\${XDG_DATA_HOME:-\$HOME/.local/share}/swiftshell"
exec "\$DATA/lib/swiftshell" "\$@"
EOF
    chmod +x "$tmp"
    mv "$tmp" "$bin"
}

swiftshell_desktop_writable() {
    desktop=$(swiftshell_desktop_path)
    if [ -e "$desktop" ] && ! swiftshell_file_marked "$desktop"; then
        swiftshell_die "refusing to overwrite an existing desktop entry."
    fi
}

swiftshell_write_desktop() {
    desktop=$(swiftshell_desktop_path)
    swiftshell_desktop_writable
    mkdir -p "$(dirname "$desktop")"
    bin=$(swiftshell_bin_path)
    tmp=$(mktemp "$(dirname "$desktop")/.swiftshell.desktop.XXXXXX")
    cat >"$tmp" <<EOF
[Desktop Entry]
Type=Application
Name=SwiftShell
Comment=Launch the SwiftShell bar
Exec=$bin start
Terminal=false
Categories=Utility;
# swiftshell-managed-launcher
EOF
    mv "$tmp" "$desktop"
}

swiftshell_remove_desktop() {
    desktop=$(swiftshell_desktop_path)
    if [ -f "$desktop" ] && swiftshell_file_marked "$desktop"; then
        rm -f "$desktop"
    elif [ -e "$desktop" ]; then
        swiftshell_warn "left an unmarked desktop entry in place."
    fi
}

swiftshell_remove_wrapper() {
    bin=$(swiftshell_bin_path)
    if [ -f "$bin" ] && swiftshell_file_marked "$bin"; then
        rm -f "$bin"
    elif [ -e "$bin" ]; then
        swiftshell_warn "left an unmarked launcher command in place."
    fi
}

swiftshell_link_status() {
    link=$(swiftshell_quickshell_link)
    app=$(swiftshell_app_dir)
    if [ -L "$link" ]; then
        target=$(readlink "$link")
        if [ "$target" = "$app" ]; then
            printf '%s\n' "linked"
            return 0
        fi
        printf '%s\n' "foreign"
        return 0
    fi
    if [ -e "$link" ]; then
        printf '%s\n' "blocked"
        return 0
    fi
    printf '%s\n' "absent"
}

swiftshell_ensure_quickshell_link() {
    link=$(swiftshell_quickshell_link)
    app=$(swiftshell_app_dir)
    parent=$(dirname "$link")
    default=$parent/shell.qml
    if [ -e "$default" ] || [ -L "$default" ]; then
        swiftshell_say "a default Quickshell config is already present and was left unchanged."
        swiftshell_say "start this shell with: swiftshell start"
    fi
    if [ -L "$link" ]; then
        target=$(readlink "$link")
        if [ "$target" = "$app" ]; then
            return 0
        fi
        swiftshell_die "a Quickshell config name is already in use and was left unchanged."
    fi
    if [ -e "$link" ]; then
        swiftshell_die "a Quickshell config name already exists and was left unchanged."
    fi
    mkdir -p "$parent"
    ln -s "$app" "$link"
}

swiftshell_remove_quickshell_link() {
    link=$(swiftshell_quickshell_link)
    app=$(swiftshell_app_dir)
    if [ -L "$link" ]; then
        target=$(readlink "$link")
        if [ "$target" = "$app" ]; then
            rm -f "$link"
            return 0
        fi
        swiftshell_warn "left the Quickshell config name in place because it points elsewhere."
        return 0
    fi
    if [ -e "$link" ]; then
        swiftshell_warn "left the Quickshell config name in place because it is not this install."
    fi
}

swiftshell_qs_help_contains() {
    bin=$1
    sub=$2
    needle=$3
    help=$("$bin" "$sub" --help 2>&1 || true)
    case $help in
        *"$needle"*) return 0 ;;
        *) return 1 ;;
    esac
}

swiftshell_qs_kill_config() {
    bin=$1
    config=$2
    # --any-display arrived after Quickshell 0.2.1. Passing it to 0.2.0
    # makes kill fail before it selects this config path.
    # The if guards keep a non-zero qs status from aborting under set -e.
    if swiftshell_qs_help_contains "$bin" kill "--any-display"; then
        if "$bin" kill --path "$config" --any-display; then
            return 0
        fi
        return 1
    fi
    if "$bin" kill --path "$config"; then
        return 0
    fi
    return 1
}

swiftshell_stop_running() {
    app=$(swiftshell_app_dir)
    if ! swiftshell_qs_bin >/dev/null 2>&1; then
        swiftshell_say "qs is not installed, so no SwiftShell process was stopped."
        return 0
    fi
    bin=$(swiftshell_qs_bin)
    if swiftshell_qs_kill_config "$bin" "$app"; then
        swiftshell_say "stop requested for this install."
        return 0
    fi
    swiftshell_warn "no running instance was confirmed for this install."
    swiftshell_warn "list shells with: qs list --all"
    return 1
}

swiftshell_require_install() {
    data=$(swiftshell_data_dir)
    if ! swiftshell_is_our_install "$data"; then
        swiftshell_die "SwiftShell is not installed. From a git checkout, run ./install.sh"
    fi
    if [ ! -f "$(swiftshell_app_dir)/shell.qml" ]; then
        swiftshell_die "the installed shell entrypoint is missing. Run ./install.sh again from a checkout."
    fi
}
