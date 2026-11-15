#!/usr/bin/env bash
# Packages the built www/ into a signed Jellyfin.wgt, using the Tizen CLI in Docker.
#
#   scripts/package.sh [version] [output.wgt]
#
# version is x.y.z (x and y at most 255); default 0.1.0. Signs with the SDK image's
# default "dev" profile, the same one the community installers use. The image is
# pinned by digest so the signing key stays the same and updates install over the
# previous build; if it ever changes, uninstall the app from the TV first.
set -euo pipefail

TIZEN_SDK_IMAGE="${TIZEN_SDK_IMAGE:-vitalets/tizen-webos-sdk@sha256:5107c8a83fae3128d3b9aa2b499a221f1e0188ebb0fa3ad5be01e9ba2eaf33dc}"
version="${1:-0.1.0}"
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${2:-$root/build/Jellyfin.wgt}"

if ! [[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || (( BASH_REMATCH[1] > 255 || BASH_REMATCH[2] > 255 || BASH_REMATCH[3] > 65535 )); then
    echo "Version must be x.y.z with x, y <= 255 and z <= 65535: $version" >&2
    exit 1
fi

if [ ! -f "$root/www/index.html" ]; then
    echo "No www/ yet: build it first (see README)" >&2
    exit 1
fi

# Stage only what the app needs, so build-web doesn't pick up node_modules and the like
stage="$root/build/app"
rm -rf "$stage" "$root/build/out"
mkdir -p "$stage" "$root/build/out" "$(dirname "$out")"
cp -R "$root/www" "$root/index.html" "$root/tizen.js" "$root/icon.png" "$stage/"
sed "s/<widget \(.*\) version=\"[^\"]*\"/<widget \1 version=\"$version\"/" "$root/config.xml" > "$stage/config.xml"
grep -q "version=\"$version\"" "$stage/config.xml" || { echo "Couldn't set the version in config.xml" >&2; exit 1; }

docker run --rm --platform linux/amd64 -e HOST_IDS="$(id -u):$(id -g)" -v "$root/build:/build" "$TIZEN_SDK_IMAGE" bash -c '
    set -e
    cd /build/app
    tizen build-web -- . > /tmp/build.log 2>&1 || { cat /tmp/build.log; exit 1; }
    tizen package -t wgt -s dev -o /build/out -- .buildResult > /tmp/package.log 2>&1 || { cat /tmp/package.log; exit 1; }
    chown -R "$HOST_IDS" /build
'

mv "$root"/build/out/*.wgt "$out"
rm -rf "$stage" "$root/build/out"
echo "Packaged $out (version $version)"
