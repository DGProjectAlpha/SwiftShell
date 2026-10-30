#!/bin/sh
# Hermetic installer tests. They use a temporary HOME and stub binaries.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PASS=0

fail() {
    printf 'not ok - %s\n' "$*" >&2
    exit 1
}

ok() {
    PASS=$((PASS + 1))
    printf 'ok - %s\n' "$*"
}

new_home() {
    HOME=$(mktemp -d)
    export HOME
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export SWIFTSHELL_OS_RELEASE="$HOME/os-release"
    export SWIFTSHELL_QS_LOG="$HOME/qs.log"
    export SWIFTSHELL_SUDO_LOG="$HOME/sudo.log"
    export SWIFTSHELL_PACMAN_LOG="$HOME/pacman.log"
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.config/hypr/config" "$HOME/.config/quickshell/noctalia"
    printf '%s\n' 'return { binds = true }' >"$HOME/.config/hypr/config/binds.lua"
    printf '%s\n' 'noctalia' >"$HOME/.config/quickshell/noctalia/shell.qml"
    printf '%s\n' 'ID=arch' >"$HOME/os-release"
    : >"$SWIFTSHELL_QS_LOG"
    export PATH="$STUBS:$BASE_PATH"
}

checksum() {
    cksum "$1" | awk '{ print $1, $2 }'
}

assert_same() {
    if ! cmp -s "$1" "$2"; then
        fail "$3"
    fi
}

write_stubs() {
    dir=$1
    mkdir -p "$dir"
    cat >"$dir/qs" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${SWIFTSHELL_QS_LOG:-/dev/null}"
case ${1:-} in
    -V|--version)
        printf '%s\n' "quickshell 0.3.0"
        exit 0
        ;;
    kill)
        if [ "${2:-}" = "--help" ]; then
            printf '%s\n' "--path --any-display --id"
            exit 0
        fi
        exit 0
        ;;
esac
exit 0
EOF
    cat >"$dir/Hyprland" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then
    printf '%s\n' "Hyprland 0.45.2 built from branch test"
    exit 0
fi
exit 0
EOF
    cat >"$dir/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${SWIFTSHELL_SUDO_LOG:-/dev/null}"
exit 99
EOF
    chmod +x "$dir/qs" "$dir/Hyprland" "$dir/sudo"
}

write_old_qs() {
    dir=$1
    mkdir -p "$dir"
    cat >"$dir/qs" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-V" ] || [ "${1:-}" = "--version" ]; then
    printf '%s\n' "quickshell 0.1.0"
    exit 0
fi
exit 0
EOF
    cp "$STUBS/Hyprland" "$dir/Hyprland"
    cp "$STUBS/sudo" "$dir/sudo"
    chmod +x "$dir/qs" "$dir/Hyprland" "$dir/sudo"
}

write_dep_stubs() {
    dir=$1
    mkdir -p "$dir"
    cat >"$dir/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${SWIFTSHELL_SUDO_LOG:-/dev/null}"
exit 0
EOF
    cat >"$dir/pacman" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${SWIFTSHELL_PACMAN_LOG:-/dev/null}"
exit 1
EOF
    chmod +x "$dir/sudo" "$dir/pacman"
}

STUBS=$(mktemp -d)
write_stubs "$STUBS"
BASE_PATH="/usr/bin:/bin"

run_install() {
    PATH="$STUBS:$BASE_PATH" "$ROOT/install.sh" "$@"
}

test_versions() {
    # shellcheck source=../scripts/lib/deps.sh
    . "$ROOT/scripts/lib/deps.sh"
    swiftshell_version_ge 0.2.0 0.2.0 || fail "0.2.0 should meet 0.2.0"
    swiftshell_version_ge 0.3.0 0.2.0 || fail "0.3.0 should meet 0.2.0"
    swiftshell_version_ge 0.2.1 0.2.0 || fail "0.2.1 should meet 0.2.0"
    if swiftshell_version_ge 0.1.9 0.2.0; then
        fail "0.1.9 should be below 0.2.0"
    fi
    [ "$(swiftshell_extract_version "quickshell 0.3.0")" = "0.3.0" ] || fail "parse quickshell"
    [ "$(swiftshell_extract_version "Tag: v0.41.2")" = "0.41.2" ] || fail "parse tag"
    [ "$(swiftshell_extract_version "Hyprland 0.45.2 built from branch test")" = "0.45.2" ] || fail "parse hyprland"
    ok "version parsing"
}

test_fresh_install() {
    new_home
    binds_sum=$(checksum "$HOME/.config/hypr/config/binds.lua")
    noctalia_sum=$(checksum "$HOME/.config/quickshell/noctalia/shell.qml")
    run_install >/dev/null
    [ -f "$XDG_DATA_HOME/swiftshell/app/shell.qml" ] || fail "app missing"
    assert_same "$ROOT/shell/shell.qml" "$XDG_DATA_HOME/swiftshell/app/shell.qml" "installed shell differs"
    [ "$(sed -n 's/^product=//p' "$XDG_DATA_HOME/swiftshell/manifest")" = "swiftshell" ] || fail "manifest"
    [ -f "$HOME/.local/bin/swiftshell" ] || fail "launcher missing"
    grep -q 'swiftshell-managed-launcher' "$HOME/.local/bin/swiftshell" || fail "launcher marker"
    [ -f "$XDG_CONFIG_HOME/swiftshell/settings.json" ] || fail "settings missing"
    [ ! -e "$XDG_CONFIG_HOME/autostart/swiftshell.desktop" ] || fail "autostart was created"
    [ ! -e "$XDG_CONFIG_HOME/systemd" ] || fail "systemd unit was created"
    [ ! -e "$XDG_CONFIG_HOME/quickshell/swiftshell" ] || fail "activation link created during install"
    [ "$(checksum "$HOME/.config/hypr/config/binds.lua")" = "$binds_sum" ] || fail "hypr config changed"
    [ "$(checksum "$HOME/.config/quickshell/noctalia/shell.qml")" = "$noctalia_sum" ] || fail "other shell changed"
    [ ! -s "$SWIFTSHELL_SUDO_LOG" ] || fail "sudo was called"
    printf '%s\n' '{ "clock": { "use24Hour": false } }' >"$XDG_CONFIG_HOME/swiftshell/settings.json"
    saved="$HOME/settings-before-update"
    cp "$XDG_CONFIG_HOME/swiftshell/settings.json" "$saved"
    run_install >/dev/null
    assert_same "$saved" "$XDG_CONFIG_HOME/swiftshell/settings.json" "settings were replaced"
    ok "install is idempotent and leaves other configs alone"
}

test_activate_cycle() {
    new_home
    printf '%s\n' 'default-shell' >"$XDG_CONFIG_HOME/quickshell/shell.qml"
    run_install >/dev/null
    "$HOME/.local/bin/swiftshell" activate >/dev/null
    [ -f "$XDG_STATE_HOME/swiftshell/active" ] || fail "active marker missing"
    [ -f "$XDG_DATA_HOME/applications/swiftshell.desktop" ] || fail "desktop entry missing"
    [ "$(readlink "$XDG_CONFIG_HOME/quickshell/swiftshell")" = "$XDG_DATA_HOME/swiftshell/app" ] || fail "link target"
    [ "$(cat "$XDG_CONFIG_HOME/quickshell/shell.qml")" = "default-shell" ] || fail "default config changed"
    [ "$(cat "$XDG_CONFIG_HOME/quickshell/noctalia/shell.qml")" = "noctalia" ] || fail "named shell changed"
    "$HOME/.local/bin/swiftshell" activate >/dev/null
    "$HOME/.local/bin/swiftshell" start >/dev/null &
    wait $! || fail "start failed"
    grep -q -- "--path $XDG_DATA_HOME/swiftshell/app" "$SWIFTSHELL_QS_LOG" || fail "start path"
    "$HOME/.local/bin/swiftshell" deactivate >/dev/null
    [ ! -e "$XDG_STATE_HOME/swiftshell/active" ] || fail "active marker remained"
    [ ! -e "$XDG_CONFIG_HOME/quickshell/swiftshell" ] || fail "link remained"
    [ ! -e "$XDG_DATA_HOME/applications/swiftshell.desktop" ] || fail "desktop entry remained"
    [ -f "$XDG_DATA_HOME/swiftshell/app/shell.qml" ] || fail "deactivate removed the install"
    [ -f "$XDG_CONFIG_HOME/swiftshell/settings.json" ] || fail "deactivate removed settings"
    grep -q 'kill --path' "$SWIFTSHELL_QS_LOG" || fail "stop was not limited to this path"
    grep 'kill --path' "$SWIFTSHELL_QS_LOG" | grep -q -- '--any-display' || fail "modern stop omitted --any-display"
    ok "activate and deactivate are reversible"
}

test_stop_on_quickshell_without_any_display() {
    new_home
    run_install >/dev/null
    old=$(mktemp -d)
    cat >"$old/qs" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${SWIFTSHELL_QS_LOG:-/dev/null}"
case ${1:-} in
    -V|--version)
        printf '%s\n' "quickshell 0.2.0"
        exit 0
        ;;
    kill)
        case ${2:-} in
            --help)
                printf '%s\n' "kill quickshell instances"
                printf '%s\n' "-p,--path"
                printf '%s\n' "-i,--id"
                exit 0
                ;;
        esac
        case " $* " in
            *" --any-display "*)
                exit 2
                ;;
        esac
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "$old/qs"
    : >"$SWIFTSHELL_QS_LOG"
    PATH="$old:$BASE_PATH" "$HOME/.local/bin/swiftshell" deactivate >/dev/null
    grep -q 'kill --path' "$SWIFTSHELL_QS_LOG" || fail "old quickshell was not stopped by path"
    if grep 'kill --path' "$SWIFTSHELL_QS_LOG" | grep -q 'any-display'; then
        fail "stop passed --any-display to a Quickshell that does not provide it"
    fi
    ok "stop omits --any-display on Quickshell 0.2"
}

test_stop_reports_a_miss() {
    new_home
    run_install >/dev/null
    miss=$(mktemp -d)
    cat >"$miss/qs" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${SWIFTSHELL_QS_LOG:-/dev/null}"
case ${1:-} in
    kill)
        if [ "${2:-}" = "--help" ]; then
            printf '%s\n' "--path --any-display"
            exit 0
        fi
        exit 1
        ;;
esac
exit 0
EOF
    chmod +x "$miss/qs"
    if PATH="$miss:$BASE_PATH" "$HOME/.local/bin/swiftshell" stop >"$HOME/stop.out" 2>"$HOME/stop.err"; then
        fail "stop succeeded when qs kill failed"
    fi
    grep -q "no running instance was confirmed" "$HOME/stop.err" || fail "stop aborted before reporting the miss"
    grep -q 'kill --path' "$SWIFTSHELL_QS_LOG" || fail "failed stop did not select a path"
    ok "stop reports a miss when qs kill fails"
}

test_blocked_name() {
    new_home
    run_install >/dev/null
    mkdir -p "$XDG_CONFIG_HOME/quickshell/swiftshell"
    printf '%s\n' 'keep' >"$XDG_CONFIG_HOME/quickshell/swiftshell/keep"
    if "$HOME/.local/bin/swiftshell" activate >/dev/null 2>&1; then
        fail "activate replaced an existing config name"
    fi
    [ "$(cat "$XDG_CONFIG_HOME/quickshell/swiftshell/keep")" = "keep" ] || fail "existing name changed"
    [ ! -f "$XDG_STATE_HOME/swiftshell/active" ] || fail "activation was recorded after refusal"
    ok "activate refuses an occupied config name"
}

test_foreign_directory() {
    new_home
    mkdir -p "$XDG_DATA_HOME/swiftshell"
    printf '%s\n' 'foreign' >"$XDG_DATA_HOME/swiftshell/foreign"
    if run_install >/dev/null 2>&1; then
        fail "install overwrote a foreign directory"
    fi
    [ "$(cat "$XDG_DATA_HOME/swiftshell/foreign")" = "foreign" ] || fail "foreign file changed"
    ok "install refuses a foreign data directory"
}

test_foreign_launcher() {
    new_home
    printf '%s\n' '#!/bin/sh' >"$HOME/.local/bin/swiftshell"
    chmod +x "$HOME/.local/bin/swiftshell"
    if run_install >/dev/null 2>&1; then
        fail "install overwrote a foreign launcher"
    fi
    [ "$(cat "$HOME/.local/bin/swiftshell")" = "#!/bin/sh" ] || fail "launcher changed"
    ok "install refuses a foreign launcher"
}

test_uninstall() {
    new_home
    run_install >/dev/null
    printf '%s\n' 'keep-me' >"$XDG_CONFIG_HOME/swiftshell/settings.json"
    printf '%s\n' 'other' >"$XDG_CONFIG_HOME/other"
    "$HOME/.local/bin/swiftshell" uninstall >/dev/null
    [ ! -e "$XDG_DATA_HOME/swiftshell/app" ] || fail "app remained"
    [ ! -e "$HOME/.local/bin/swiftshell" ] || fail "launcher remained"
    [ "$(cat "$XDG_CONFIG_HOME/swiftshell/settings.json")" = "keep-me" ] || fail "settings removed"
    [ "$(cat "$XDG_CONFIG_HOME/other")" = "other" ] || fail "unrelated config removed"
    "$ROOT/scripts/swiftshell" uninstall >/dev/null
    ok "uninstall keeps settings"

    new_home
    run_install >/dev/null
    printf '%s\n' 'other' >"$XDG_CONFIG_HOME/other"
    "$HOME/.local/bin/swiftshell" uninstall --purge-settings >/dev/null
    [ ! -e "$XDG_CONFIG_HOME/swiftshell" ] || fail "settings remained after purge"
    [ "$(cat "$XDG_CONFIG_HOME/other")" = "other" ] || fail "purge removed an unrelated file"
    [ ! -e "$XDG_DATA_HOME/swiftshell/app" ] || fail "purge left the app"
    ok "purge removes only the settings directory"
}

test_strict_version() {
    new_home
    old=$(mktemp -d)
    write_old_qs "$old"
    if PATH="$old:$BASE_PATH" "$ROOT/install.sh" --strict >/dev/null 2>&1; then
        fail "strict install accepted an old Quickshell"
    fi
    [ ! -e "$XDG_DATA_HOME/swiftshell/manifest" ] || fail "strict failure still installed files"
    ok "strict mode stops before writing files"
}

test_optional_deps() {
    new_home
    deps=$(mktemp -d)
    write_dep_stubs "$deps"
    PATH="$deps:$BASE_PATH" "$ROOT/install.sh" --install-deps --yes >/dev/null
    grep -q 'pacman -S' "$SWIFTSHELL_SUDO_LOG" || fail "pacman was not requested"
    grep -q 'quickshell' "$SWIFTSHELL_SUDO_LOG" || fail "quickshell package missing"
    grep -q 'hyprland' "$SWIFTSHELL_SUDO_LOG" || fail "hyprland package missing"
    [ -f "$XDG_DATA_HOME/swiftshell/manifest" ] || fail "files were not installed after the package step"
    [ ! -e "$HOME/.config/hypr/hyprland.conf" ] || fail "package step wrote a hyprland config"
    ok "optional dependency installation is explicit"
}

test_versions
test_fresh_install
test_activate_cycle
test_stop_on_quickshell_without_any_display
test_stop_reports_a_miss
test_blocked_name
test_foreign_directory
test_foreign_launcher
test_uninstall
test_strict_version
test_optional_deps

printf 'install tests passed (%s)\n' "$PASS"
