# Read-only health report and a settings-only restore.
# This file does not read or write Hyprland or Noctalia paths.

swiftshell_notification_ownership() {
    file=$1
    if [ ! -e "$file" ]; then
        printf '%s\n' "absent"
        return 0
    fi
    if [ -L "$file" ] || [ ! -f "$file" ]; then
        printf '%s\n' "unreadable"
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        printf '%s\n' "unreadable"
        return 0
    fi
    python3 - "$file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    print("unreadable")
    raise SystemExit(0)
notes = data.get("notifications") if isinstance(data, dict) else None
own = notes.get("ownership") if isinstance(notes, dict) else None
print(own if own in ("off", "on") else "unreadable")
PY
}

swiftshell_doctor() {
    swiftshell_need_home
    swiftshell_say "doctor"
    swiftshell_say "Hyprland and Noctalia files were not read or written."
    swiftshell_report_dependencies || true
    swiftshell_say "blur: unavailable. Quickshell 0.2 has no BackgroundEffect. Surfaces use a translucent scrim."
    swiftshell_say "outputs: not measured. This command does not read a layout."
    config=$(swiftshell_config_dir)
    settings=$config/settings.json
    backup=$settings.bak-swiftshell
    if [ -e "$settings" ]; then
        swiftshell_say "settings file: present"
    else
        swiftshell_say "settings file: absent"
    fi
    if [ -f "$backup" ] && [ ! -L "$backup" ]; then
        swiftshell_say "settings backup: present"
    else
        swiftshell_say "settings backup: absent"
    fi
    swiftshell_say "notification ownership: $(swiftshell_notification_ownership "$settings")"
    case ":$PATH:" in
        *:"$HOME/.local/bin":*)
            swiftshell_say "launcher directory: on PATH"
            ;;
        *)
            swiftshell_say "launcher directory: not on PATH. Shell startup files were not edited."
            ;;
    esac
}

swiftshell_rollback_settings() {
    swiftshell_need_home
    config=$(swiftshell_config_dir)
    swiftshell_assert_managed_path "$config"
    settings=$config/settings.json
    backup=$settings.bak-swiftshell
    if [ -L "$settings" ] || [ -L "$backup" ]; then
        swiftshell_die "refusing to restore through a symlink."
    fi
    if [ ! -f "$backup" ]; then
        swiftshell_die "no settings backup to restore."
    fi
    tmp=$(mktemp "$config/settings.json.XXXXXX")
    if ! cp "$backup" "$tmp"; then
        rm -f "$tmp"
        swiftshell_die "the settings backup could not be copied."
    fi
    mv "$tmp" "$settings"
    swiftshell_say "restored settings from the SwiftShell backup."
    swiftshell_say "Hyprland and Noctalia files were not read or written."
}
