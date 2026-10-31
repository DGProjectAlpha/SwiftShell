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
    data=$(swiftshell_data_dir)
    if swiftshell_is_our_install "$data" && [ -f "$(swiftshell_app_dir)/shell.qml" ]; then
        swiftshell_say "runtime files: present"
    else
        swiftshell_say "runtime files: missing or foreign"
    fi
    if [ "${SWIFTSHELL_PACKAGE_INSTALL:-0}" = 1 ]; then
        swiftshell_say "install type: system package"
    else
        swiftshell_say "install type: user"
    fi
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

swiftshell_restore_backup_text() {
    file=$1
    if ! command -v python3 >/dev/null 2>&1; then
        swiftshell_die "python3 is required to restore a settings backup."
    fi
    python3 - "$file" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    text = handle.read()

def looks(value):
    return isinstance(value, dict) and (
        isinstance(value.get("version"), int)
        or isinstance(value.get("clock"), dict)
        or isinstance(value.get("bar"), dict)
    )

try:
    parsed = json.loads(text)
except Exception:
    raise SystemExit(1)

restored = None
if looks(parsed):
    restored = text
elif isinstance(parsed, dict) and isinstance(parsed.get("document"), str):
    try:
        inner = json.loads(parsed["document"])
    except Exception:
        inner = None
    if looks(inner):
        restored = parsed["document"]

if restored is None:
    raise SystemExit(1)
sys.stdout.write(restored)
if not restored.endswith("\n"):
    sys.stdout.write("\n")
PY
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
    if ! swiftshell_restore_backup_text "$backup" >"$tmp"; then
        rm -f "$tmp"
        swiftshell_die "the settings backup is not a SwiftShell settings file."
    fi
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        swiftshell_die "the settings backup is not a SwiftShell settings file."
    fi
    mv "$tmp" "$settings"
    swiftshell_say "restored settings from the SwiftShell backup."
    swiftshell_say "Hyprland and Noctalia files were not read or written."
}
