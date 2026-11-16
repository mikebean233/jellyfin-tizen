#!/usr/bin/env bash
# Runs the web fork's dev server in Docker, for quick UI iteration in a desktop browser.
#
#   scripts/web-dev.sh [--tv] [--tizen VERSION] [--web DIR] [--port PORT]
#
#   --tv            TV simulator: runs this repo's tizen.js against simulated Tizen
#                   APIs (sim/), with the keyboard as the remote and no mouse.
#                   Uses port 8088, so it keeps its own sign-in and settings.
#   --tizen VER     Tizen version to report with --tv: 5.5, 6.0, 6.5 (default), 7.0, 8.0
#   --web DIR       jellyfin-web checkout (default ../samsung-friendly-jellyfin-web)
#   --port PORT     default 8080, or 8088 with --tv
#
# Open http://localhost:PORT and add your server. Without --tv, set Settings >
# Display > Layout to TV. Edits under src/ (and to tizen.js and sim/ with --tv)
# reload the page. Ctrl+C stops it.
set -euo pipefail

NODE_IMAGE="${NODE_IMAGE:-node:24}"
root="$(cd "$(dirname "$0")/.." && pwd)"
web="$root/../samsung-friendly-jellyfin-web"
port=""
tv=false
tizen_version=6.5
while [ $# -gt 0 ]; do
    case "$1" in
        --tv) tv=true ;;
        --tizen) tizen_version="$2"; shift ;;
        --web) web="$2"; shift ;;
        --port) port="$2"; shift ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done
web="$(cd "$web" && pwd)"
[ -f "$web/webpack.dev.js" ] || { echo "Not a jellyfin-web checkout: $web" >&2; exit 1; }
grep -q DEV_HEAD_SCRIPTS "$web/webpack.dev.js" || ! $tv || { echo "--tv needs the dev server changes in the web fork (dev-server-plugins)" >&2; exit 1; }

tv_args=()
if $tv; then
    port="${port:-8088}"
    tv_args=(-v "$root:/tizen:ro" -e TV_SIM_TIZEN_VERSION="$tizen_version"
        -e DEV_HEAD_SCRIPTS=/tizen/sim/tizen-shim.js,/tizen/tizen.js,/tizen/sim/remote.js)
fi
port="${port:-8080}"

# Same node_modules volume as tv.sh, and the same CPU limit (see tv.sh)
docker run --rm -it --cpuset-cpus "${BUILD_CPUS:-0-3}" -p "$port:8080" ${tv_args[@]+"${tv_args[@]}"} \
    -v "$web:/src" -v jellyfin-tizen-web-modules:/src/node_modules -w /src "$NODE_IMAGE" bash -c '
        set -e
        if ! cmp -s package-lock.json node_modules/.installed-lock 2>/dev/null; then
            npm ci --no-audit --loglevel=error && cp package-lock.json node_modules/.installed-lock
        fi
        echo "Starting; open http://localhost:'"$port"' once it has compiled"
        npx webpack serve --config webpack.dev.js --host 0.0.0.0'
