#!/usr/bin/env bash
set -euo pipefail

base_url="https://raw.githubusercontent.com/vuecwiz/vnstat-json-dash/main"

bin_dir="/usr/local/bin"
unit_dir="/etc/systemd/system"
web_dir="/var/lib/vnstat/json"

if [ "${1:-}" = "--uninstall" ] && [ "$#" -eq 1 ]; then
    if command -v systemctl >/dev/null 2>&1 && [ -d "$unit_dir" ]; then
        systemctl disable --now vnstat-json.timer 2>/dev/null || true
        systemctl stop vnstat-json.service 2>/dev/null || true
    fi

    rm -f -- \
        "$bin_dir/vnstat-json" \
        "$unit_dir/vnstat-json.service" \
        "$unit_dir/vnstat-json.timer" \
        "$web_dir/index.html" \
        "$web_dir/chart.js" \
        "$web_dir/chartjs-plugin-zoom.min.js" \
        "$web_dir/hammer.min.js" \
        "$web_dir/.vnstat-json.lock"

    find "$web_dir" -maxdepth 1 -type f -name 'vnstat_*.json' -delete 2>/dev/null || true
    rmdir "$web_dir" 2>/dev/null || true

    if command -v systemctl >/dev/null 2>&1 && [ -d "$unit_dir" ]; then
        systemctl daemon-reload
        systemctl reset-failed vnstat-json.service 2>/dev/null || true
    fi

    echo "Uninstalled vnstat-json-dash."
    exit 0
fi

if [ "$#" -ne 0 ]; then
    echo "Usage: $0 [--uninstall]" >&2
    exit 2
fi

command -v install >/dev/null 2>&1 || {
    echo "install (coreutils) is required" >&2
    exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$script_dir" ] \
    && [ -f "$script_dir/scripts/vnstat-json" ] \
    && [ -f "$script_dir/systemd/vnstat-json.service" ] \
    && [ -f "$script_dir/systemd/vnstat-json.timer" ] \
    && [ -f "$script_dir/www/index.html" ] \
    && [ -f "$script_dir/www/chart.js" ] \
    && [ -f "$script_dir/www/chartjs-plugin-zoom.min.js" ] \
    && [ -f "$script_dir/www/hammer.min.js" ]; then
    install -m 0755 "$script_dir/scripts/vnstat-json" "$tmp_dir/vnstat-json"
    install -m 0644 \
        "$script_dir/systemd/vnstat-json.service" \
        "$script_dir/systemd/vnstat-json.timer" \
        "$script_dir/www/index.html" \
        "$script_dir/www/chart.js" \
        "$script_dir/www/chartjs-plugin-zoom.min.js" \
        "$script_dir/www/hammer.min.js" \
        "$tmp_dir/"
else
    command -v curl >/dev/null 2>&1 || {
        echo "curl is required" >&2
        exit 1
    }
    curl --fail --silent --show-error --location \
        "$base_url/scripts/vnstat-json" \
        -o "$tmp_dir/vnstat-json"
    curl --fail --silent --show-error --location \
        "$base_url/systemd/vnstat-json.service" \
        -o "$tmp_dir/vnstat-json.service"
    curl --fail --silent --show-error --location \
        "$base_url/systemd/vnstat-json.timer" \
        -o "$tmp_dir/vnstat-json.timer"

    for asset in index.html chart.js chartjs-plugin-zoom.min.js hammer.min.js; do
        curl --fail --silent --show-error --location \
            "$base_url/www/$asset" \
            -o "$tmp_dir/$asset"
    done
fi

install -d "$bin_dir"
install -m 0755 "$tmp_dir/vnstat-json" "$bin_dir/vnstat-json"

install -d -m 0755 "$web_dir"
install -m 0644 \
    "$tmp_dir/index.html" \
    "$tmp_dir/chart.js" \
    "$tmp_dir/chartjs-plugin-zoom.min.js" \
    "$tmp_dir/hammer.min.js" \
    "$web_dir/"

if id vnstat >/dev/null 2>&1; then
    chown vnstat:vnstat "$web_dir"
fi

if command -v systemctl >/dev/null 2>&1 && [ -d "$unit_dir" ]; then
    install -m 0644 "$tmp_dir/vnstat-json.service" "$unit_dir/vnstat-json.service"
    install -m 0644 "$tmp_dir/vnstat-json.timer" "$unit_dir/vnstat-json.timer"
    systemctl daemon-reload
    systemctl enable --now vnstat-json.timer
    echo "Installed vnstat-json-dash and enabled vnstat-json.timer."
else
    echo "Installed vnstat-json at $bin_dir/vnstat-json and dashboard assets at $web_dir."
    echo "systemd was not found; invoke it from cron or another scheduler."
fi
