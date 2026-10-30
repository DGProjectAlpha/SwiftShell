# Dependency detection and optional Arch package installation.

SWIFTSHELL_MIN_QUICKSHELL=0.2.0
SWIFTSHELL_MIN_HYPRLAND=0.40.0

swiftshell_extract_version() {
    printf '%s\n' "$1" | tr ' ' '\n' | sed -n 's/^[vV]\{0,1\}\([0-9][0-9]*\.[0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}\).*/\1/p' | head -n 1
}

swiftshell_version_ge() {
    awk -v installed="$1" -v minimum="$2" 'BEGIN {
        split(installed, a, ".")
        split(minimum, b, ".")
        for (i = 1; i <= 3; i++) {
            ai = a[i] + 0
            bi = b[i] + 0
            if (ai > bi) exit 0
            if (ai < bi) exit 1
        }
        exit 0
    }'
}

swiftshell_os_release_file() {
    if [ -n "${SWIFTSHELL_OS_RELEASE:-}" ]; then
        printf '%s\n' "$SWIFTSHELL_OS_RELEASE"
    else
        printf '%s\n' /etc/os-release
    fi
}

swiftshell_is_arch() {
    file=$(swiftshell_os_release_file)
    if [ ! -f "$file" ]; then
        return 1
    fi
    id=$(sed -n 's/^ID=//p' "$file" | head -n 1 | tr -d '"')
    id_like=$(sed -n 's/^ID_LIKE=//p' "$file" | head -n 1 | tr -d '"')
    case "$id $id_like" in
        *arch*|*cachyos*) return 0 ;;
    esac
    return 1
}

swiftshell_qs_version_text() {
    if ! swiftshell_qs_bin >/dev/null 2>&1; then
        return 1
    fi
    bin=$(swiftshell_qs_bin)
    "$bin" -V 2>&1 || "$bin" --version 2>&1 || true
}

swiftshell_have_hyprland() {
    if command -v Hyprland >/dev/null 2>&1; then
        return 0
    fi
    if command -v hyprctl >/dev/null 2>&1; then
        return 0
    fi
    if command -v pacman >/dev/null 2>&1; then
        pacman -Q hyprland >/dev/null 2>&1 && return 0
    fi
    return 1
}

swiftshell_hyprland_version_text() {
    if command -v Hyprland >/dev/null 2>&1; then
        Hyprland --version 2>&1 || return 1
        return 0
    fi
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl version 2>&1 || return 1
        return 0
    fi
    if command -v pacman >/dev/null 2>&1; then
        pacman -Q hyprland 2>&1 || return 1
        return 0
    fi
    return 1
}

swiftshell_report_dependencies() {
    ok=0
    swiftshell_say "dependency check"
    if text=$(swiftshell_qs_version_text); then
        version=$(swiftshell_extract_version "$text")
        if [ -z "$version" ]; then
            swiftshell_warn "Quickshell was found, but its version string was not recognized."
            ok=1
        elif swiftshell_version_ge "$version" "$SWIFTSHELL_MIN_QUICKSHELL"; then
            swiftshell_say "Quickshell $version meets the minimum $SWIFTSHELL_MIN_QUICKSHELL."
        else
            swiftshell_warn "Quickshell $version is older than the minimum $SWIFTSHELL_MIN_QUICKSHELL."
            ok=1
        fi
    else
        swiftshell_warn "Quickshell was not found on PATH."
        ok=1
    fi

    if text=$(swiftshell_hyprland_version_text); then
        version=$(swiftshell_extract_version "$text")
        if [ -z "$version" ]; then
            swiftshell_warn "Hyprland was found, but its version string was not recognized."
        elif swiftshell_version_ge "$version" "$SWIFTSHELL_MIN_HYPRLAND"; then
            swiftshell_say "Hyprland $version meets the recorded minimum $SWIFTSHELL_MIN_HYPRLAND."
        else
            swiftshell_warn "Hyprland $version is older than the recorded minimum $SWIFTSHELL_MIN_HYPRLAND."
        fi
    else
        swiftshell_warn "Hyprland was not reported by a local version command."
    fi
    return "$ok"
}

swiftshell_install_missing_deps() {
    if [ "${SWIFTSHELL_INSTALL_DEPS:-0}" != 1 ]; then
        return 0
    fi

    packages=""
    if ! swiftshell_qs_bin >/dev/null 2>&1; then
        packages="$packages quickshell"
    fi
    if ! swiftshell_have_hyprland; then
        packages="$packages hyprland"
    fi
    if [ -z "$packages" ]; then
        swiftshell_say "required packages are already present."
        return 0
    fi

    if ! swiftshell_is_arch || ! command -v pacman >/dev/null 2>&1; then
        swiftshell_warn "automatic package installation is available on Arch-based systems with pacman."
        swiftshell_warn "install these packages with the system package manager:$packages"
        return 1
    fi

    if [ "${SWIFTSHELL_ASSUME_YES:-0}" != 1 ]; then
        printf 'SwiftShell: install with pacman:%s ? [y/N] ' "$packages"
        read -r answer || answer=n
        case $answer in
            y|Y|yes|YES) ;;
            *)
                swiftshell_say "package installation skipped."
                return 0
                ;;
        esac
    fi

    # Package names above are fixed. They are not taken from the user.
    if [ "${SWIFTSHELL_ASSUME_YES:-0}" = 1 ]; then
        # shellcheck disable=SC2086
        sudo pacman -S --needed --noconfirm $packages
    else
        # shellcheck disable=SC2086
        sudo pacman -S --needed $packages
    fi
}
