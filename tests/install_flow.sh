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
    export SWIFTSHELL_DECOY_LOG="$HOME/decoy.log"
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.config/hypr/config" "$HOME/.config/quickshell/noctalia"
    printf '%s\n' 'return { binds = true }' >"$HOME/.config/hypr/config/binds.lua"
    printf '%s\n' 'noctalia' >"$HOME/.config/quickshell/noctalia/shell.qml"
    printf '%s\n' 'ID=arch' >"$HOME/os-release"
    : >"$SWIFTSHELL_QS_LOG"
    : >"$SWIFTSHELL_SUDO_LOG"
    : >"$SWIFTSHELL_PACMAN_LOG"
    : >"$SWIFTSHELL_DECOY_LOG"
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

isolated_tools() {
    dir=$(mktemp -d)
    tool=""
    src=""
    for tool in mkdir cp chmod sed grep cat printf ln rm mv head tr awk ls mktemp date readlink dirname; do
        src=$(PATH="$ORIG_PATH" command -v "$tool" 2>/dev/null || true)
        if [ -z "$src" ]; then
            fail "required test tool missing: $tool"
        fi
        ln -s "$src" "$dir/$tool"
    done
    src=$(PATH="$ORIG_PATH" command -v git 2>/dev/null || true)
    if [ -n "$src" ]; then
        ln -s "$src" "$dir/git"
    fi
    printf '%s\n' "$dir"
}

write_decoy_commands() {
    dir=$1
    mkdir -p "$dir"
    cat >"$dir/qs" <<'EOF'
#!/bin/sh
printf '%s\n' "qs $*" >>"${SWIFTSHELL_DECOY_LOG:-/dev/null}"
printf '%s\n' "quickshell 9.9.9"
exit 0
EOF
    cat >"$dir/quickshell" <<'EOF'
#!/bin/sh
printf '%s\n' "quickshell $*" >>"${SWIFTSHELL_DECOY_LOG:-/dev/null}"
exit 0
EOF
    cat >"$dir/Hyprland" <<'EOF'
#!/bin/sh
printf '%s\n' "Hyprland $*" >>"${SWIFTSHELL_DECOY_LOG:-/dev/null}"
if [ "${1:-}" = "--version" ]; then
    printf '%s\n' "Hyprland 9.9.9"
fi
exit 0
EOF
    cat >"$dir/hyprctl" <<'EOF'
#!/bin/sh
printf '%s\n' "hyprctl $*" >>"${SWIFTSHELL_DECOY_LOG:-/dev/null}"
exit 0
EOF
    chmod +x "$dir/qs" "$dir/quickshell" "$dir/Hyprland" "$dir/hyprctl"
}

assert_host_path_hidden() {
    case ":$1:" in
        *:/usr/bin:*|*:/usr/local/bin:*|*:/bin:*)
            fail "dependency test PATH includes a host bin directory"
            ;;
    esac
}

ORIG_PATH=$PATH
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
    bin=$(isolated_tools)
    write_dep_stubs "$bin"
    decoy=$(mktemp -d)
    write_decoy_commands "$decoy"
    assert_host_path_hidden "$bin"
    if PATH="$bin" command -v qs >/dev/null 2>&1; then
        fail "missing-deps PATH can see qs"
    fi
    if PATH="$bin" command -v Hyprland >/dev/null 2>&1; then
        fail "missing-deps PATH can see Hyprland"
    fi
    if PATH="$bin" command -v hyprctl >/dev/null 2>&1; then
        fail "missing-deps PATH can see hyprctl"
    fi
    if PATH="$bin:$decoy" command -v qs >/dev/null 2>&1; then
        :
    else
        fail "decoy qs was not executable"
    fi
    PATH="$bin" "$ROOT/install.sh" --install-deps --yes >/dev/null
    [ ! -s "$SWIFTSHELL_DECOY_LOG" ] || fail "a decoy compositor command was executed"
    grep -q 'pacman -S' "$SWIFTSHELL_SUDO_LOG" || fail "pacman was not requested"
    grep -q 'quickshell' "$SWIFTSHELL_SUDO_LOG" || fail "quickshell package missing"
    grep -q 'hyprland' "$SWIFTSHELL_SUDO_LOG" || fail "hyprland package missing"
    if grep -q -- '-S' "$SWIFTSHELL_PACMAN_LOG"; then
        fail "pacman -S ran outside the sudo stub"
    fi
    [ -f "$XDG_DATA_HOME/swiftshell/manifest" ] || fail "files were not installed after the package step"
    [ ! -e "$HOME/.config/hypr/hyprland.conf" ] || fail "package step wrote a hyprland config"
    ok "optional dependency installation is explicit"
}

test_optional_deps_already_present() {
    new_home
    bin=$(isolated_tools)
    cp "$STUBS/qs" "$bin/qs"
    cp "$STUBS/Hyprland" "$bin/Hyprland"
    chmod +x "$bin/qs" "$bin/Hyprland"
    write_dep_stubs "$bin"
    assert_host_path_hidden "$bin"
    PATH="$bin" "$ROOT/install.sh" --install-deps --yes >/dev/null
    [ ! -s "$SWIFTSHELL_SUDO_LOG" ] || fail "pacman was requested for packages that are already present"
    [ -f "$XDG_DATA_HOME/swiftshell/manifest" ] || fail "present dependencies skipped the file install"
    ok "present dependencies do not request pacman"
}

test_optional_deps_sudo_failure() {
    new_home
    bin=$(isolated_tools)
    write_dep_stubs "$bin"
    cat >"$bin/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${SWIFTSHELL_SUDO_LOG:-/dev/null}"
exit 99
EOF
    chmod +x "$bin/sudo"
    assert_host_path_hidden "$bin"
    if PATH="$bin" "$ROOT/install.sh" --install-deps --yes --strict >"$HOME/strict.out" 2>"$HOME/strict.err"; then
        fail "strict install continued after sudo failed"
    fi
    [ ! -e "$XDG_DATA_HOME/swiftshell/manifest" ] || fail "strict sudo failure still installed files"
    grep -q 'pacman -S' "$SWIFTSHELL_SUDO_LOG" || fail "strict failure did not request pacman"
    : >"$SWIFTSHELL_SUDO_LOG"
    if PATH="$bin" "$ROOT/install.sh" --install-deps --yes >"$HOME/loose.out" 2>"$HOME/loose.err"; then
        :
    else
        fail "non-strict install aborted when sudo failed"
    fi
    grep -q 'package installation did not finish' "$HOME/loose.err" || fail "sudo failure was not reported"
    [ -f "$XDG_DATA_HOME/swiftshell/manifest" ] || fail "non-strict install dropped the files"
    [ ! -e "$HOME/.config/hypr/hyprland.conf" ] || fail "sudo failure wrote a hyprland config"
    ok "sudo failure is contained"
}

test_request_launcher() {
    new_home
    binds_sum=$(checksum "$HOME/.config/hypr/config/binds.lua")
    "$ROOT/scripts/swiftshell" request-launcher >/dev/null
    [ -s "$XDG_STATE_HOME/swiftshell/launcher.request" ] || fail "launcher request was not written"
    grep -q '"text"' "$XDG_STATE_HOME/swiftshell/launcher.request" || fail "launcher request is not json"
    [ "$(checksum "$HOME/.config/hypr/config/binds.lua")" = "$binds_sum" ] || fail "launcher request edited hypr binds"
    [ ! -e "$HOME/.config/hypr/hyprland.conf" ] || fail "launcher request wrote a hyprland config"
    ok "launcher request does not touch Hyprland"
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
test_optional_deps_already_present
test_optional_deps_sudo_failure
test_request_launcher

printf 'install tests passed (%s)\n' "$PASS"
