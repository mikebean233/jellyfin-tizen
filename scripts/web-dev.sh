#!/usr/bin/env bash
# Runs the web fork's dev server in Docker, for quick UI iteration in a desktop browser.
#
#   scripts/web-dev.sh [--web DIR] [--port PORT]
#
#   --web DIR     jellyfin-web checkout (default ../samsung-friendly-jellyfin-web)
#   --port PORT   default 8080
#
# Open http://localhost:PORT, add your server, and set Settings > Display > Layout
# to TV. Edits under src/ reload in the browser. Ctrl+C stops it.
set -euo pipefail

NODE_IMAGE="${NODE_IMAGE:-node:24}"
root="$(cd "$(dirname "$0")/.." && pwd)"
web="$root/../samsung-friendly-jellyfin-web"
port=8080
while [ $# -gt 0 ]; do
    case "$1" in
        --web) web="$2"; shift ;;
        --port) port="$2"; shift ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done
web="$(cd "$web" && pwd)"
[ -f "$web/webpack.dev.js" ] || { echo "Not a jellyfin-web checkout: $web" >&2; exit 1; }

# Same node_modules volume as tv.sh, and the same CPU limit (see tv.sh)
docker run --rm -it --cpuset-cpus "${BUILD_CPUS:-0-3}" -p "$port:8080" \
    -v "$web:/src" -v jellyfin-tizen-web-modules:/src/node_modules -w /src "$NODE_IMAGE" bash -c '
        set -e
        if ! cmp -s package-lock.json node_modules/.installed-lock 2>/dev/null; then
            npm ci --no-audit --loglevel=error && cp package-lock.json node_modules/.installed-lock
        fi
        echo "Starting; open http://localhost:'"$port"' once it has compiled"
        npx webpack serve --config webpack.dev.js --host 0.0.0.0'
