#!/usr/bin/env bash
# Builds the app from a local jellyfin-web checkout and installs it on a TV in
# Developer Mode. Everything runs in Docker, so only Docker is needed.
#
#   scripts/tv.sh <TV IP> [--web DIR] [--skip-web] [--dev]
#
#   --web DIR    jellyfin-web checkout (default ../samsung-friendly-jellyfin-web)
#   --skip-web   reuse DIR/dist as is (when only tizen.js or config.xml changed)
#   --dev        development web build: unminified, quicker to debug
#
# The TV's Developer Mode "Host PC IP" must be this computer's address.
set -euo pipefail

NODE_IMAGE="${NODE_IMAGE:-node:24}"
TIZEN_SDK_IMAGE="${TIZEN_SDK_IMAGE:-vitalets/tizen-webos-sdk@sha256:5107c8a83fae3128d3b9aa2b499a221f1e0188ebb0fa3ad5be01e9ba2eaf33dc}"
root="$(cd "$(dirname "$0")/.." && pwd)"

tv=""
web="$root/../samsung-friendly-jellyfin-web"
skip_web=false
web_build=build:production
while [ $# -gt 0 ]; do
    case "$1" in
        --web) web="$2"; shift ;;
        --skip-web) skip_web=true ;;
        --dev) web_build=build:development ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) tv="$1" ;;
    esac
    shift
done
[ -n "$tv" ] || { sed -n '2,12p' "$0"; exit 1; }
web="$(cd "$web" && pwd)"

# Linux node_modules live in Docker volumes, so they don't clash with any on the Mac.
# webpack starts a minifier per CPU, which runs Docker's VM out of memory on big
# machines, so builds get a few CPUs (BUILD_CPUS, a cpuset like 0-3).
in_node() {
    local dir="$1" volume="$2"; shift 2
    docker run --rm --cpuset-cpus "${BUILD_CPUS:-0-3}" -e USE_SYSTEM_FONTS=1 -e JELLYFIN_WEB_DIR=/web/dist \
        -v "$dir:/src" -v "$volume:/src/node_modules" -v "$web:/web" \
        -w /src "$NODE_IMAGE" bash -c "$*"
}

if ! $skip_web; then
    echo "==> Building jellyfin-web ($web_build) from $web"
    in_node "$web" jellyfin-tizen-web-modules '
        set -e
        # Reinstall only when package-lock.json changes
        if ! cmp -s package-lock.json node_modules/.installed-lock 2>/dev/null; then
            npm ci --no-audit --loglevel=error && cp package-lock.json node_modules/.installed-lock
        fi
        npm run '"$web_build"' --silent > /tmp/web.log 2>&1 || { tail -40 /tmp/web.log; exit 1; }'
fi
[ -f "$web/dist/index.html" ] || { echo "No $web/dist: build without --skip-web first" >&2; exit 1; }

echo "==> Building www"
in_node "$root" jellyfin-tizen-modules '
    set -e
    if ! cmp -s package-lock.json node_modules/.installed-lock 2>/dev/null; then
        npm ci --no-audit --loglevel=error --ignore-scripts && cp package-lock.json node_modules/.installed-lock
    fi
    npx gulp > /tmp/gulp.log 2>&1 || { cat /tmp/gulp.log; exit 1; }'

echo "==> Packaging"
"$root/scripts/package.sh" "${VERSION:-0.1.0}"

echo "==> Installing on $tv"
docker run --rm --platform linux/amd64 -v "$root/build:/build" "$TIZEN_SDK_IMAGE" bash -c '
    set -e
    sdb connect "'"$tv"'" > /dev/null
    target=$(sdb devices | awk "NR > 1 && \$2 == \"device\" { print \$3; exit }")
    [ -n "$target" ] || { echo "TV not connected: is Developer Mode on, with this computer as Host PC IP?" >&2; exit 1; }
    tizen install -n Jellyfin.wgt -t "$target" -- /build | grep -v "^\s*$"
    tizen run -p SFJellyfin.Jellyfin -t "$target" > /dev/null || echo "Installed; open it from Apps on the TV"'
echo "==> Done"
