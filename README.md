<h1 align="center">Jellyfin for Tizen</h1>
<h3 align="center">Part of the <a href="https://jellyfin.org">Jellyfin Project</a></h3>

---

<p align="center">
<img alt="Logo Banner" src="https://raw.githubusercontent.com/jellyfin/jellyfin-ux/master/branding/SVG/banner-logo-solid.svg?sanitize=true"/>
</p>

## This fork

A custom build of the Samsung TV app, bundling [samsung-friendly-jellyfin-web](https://github.com/mikebean233/samsung-friendly-jellyfin-web) instead of the stock web client.

- **Installs alongside the store app.** It has its own app ID (`SFJellyfin.Jellyfin`) and shows up as "Jellyfin (custom)". It keeps its own sign-in, so you sign in to your server once in it.
- **Loads server plugin scripts.** A browser gets plugin UI (such as [QuickTag](https://github.com/mikebean233/jellyfin-quicktag-plugin)) from the page the server sends, but this app ships its own page. After you sign in, `tizen.js` loads each script in `serverScripts` from the server instead. A server without that plugin just answers 404.
- **CI builds the app.** Each push builds `Jellyfin.wgt` from the web fork's `release-12.4` branch (set `WEB_REF` in `.github/workflows/build.yaml`, or pick a ref when running it by hand) and uploads it as an artifact. It's signed with the Tizen SDK image's default certificate, which TVs in Developer Mode accept. A `vX.Y.Z` tag attaches it to a release, and the app's version is set from the tag.

### Install a release

Put the TV in [Developer Mode](#deploy-to-tv) with this computer as Host PC IP, then:

```sh
docker run --rm --platform linux/amd64 \
  -e GITHUB_REPO=mikebean233/jellyfin-tizen -e WGT_FILE=Jellyfin -e RELEASE_TAG=v1.0.0 \
  ghcr.io/gardner/install-wgt-tizen <TV IP>
```

### Iterate locally

`scripts/tv.sh` builds your local web checkout, packages it and installs it on the TV, all in Docker:

```sh
scripts/tv.sh <TV IP>               # web from ../samsung-friendly-jellyfin-web
scripts/tv.sh <TV IP> --skip-web    # only tizen.js or config.xml changed
scripts/tv.sh <TV IP> --dev         # unminified web build, easier to debug
```

It takes about a minute. For UI work, iterating in a desktop browser is quicker:

```sh
scripts/web-dev.sh                  # dev server for ../samsung-friendly-jellyfin-web on http://localhost:8080
```

Add your server, sign in, and set **Settings → Display → Layout** to **TV**. Edits under `src/` reload in a few seconds, and plugin scripts such as QuickTag load from the server as they do on the TV. Then use `tv.sh` to check the result on the TV.

If an install is refused with "Author certificate not match" (the signing key changed) or because the installed version is newer, uninstall the app from the TV and run it again. `VERSION=x.y.z scripts/tv.sh ...` sets the version.

Keep the web branch on the same version as your server.

## Build Process
_Also look [Wiki](https://github.com/jellyfin/jellyfin-tizen/wiki)._

### Prerequisites
* Tizen Studio 4.6+ with IDE or Tizen Studio 4.6+ with CLI. See [Installing TV SDK](https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/installing-tv-sdk.html).
* Git
* Node.js 20+

### Getting Started

1. Install prerequisites.
2. Install Certificate Manager using Tizen Studio Package Manager. See [Installing Required Extensions](https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/installing-tv-sdk.html#Installing-Required-Extensions).
3. Setup Tizen certificate in Certificate Manager. See [Creating Certificates](https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/creating-certificates.html).
   > If you have installation problems with the Tizen certificate, try creating a Samsung certificate. In this case, you will also need a Samsung account.
4. Clone or download [Jellyfin Web repository](https://github.com/jellyfin/jellyfin-web).

   > It is recommended that the web version match the server version.

   ```sh
   git clone -b release-10.10.z https://github.com/jellyfin/jellyfin-web.git
   ```
   > Replace `release-10.10.z` with the name of the branch you want to build.

   > You can also use `git checkout` to switch branches.
5. Clone or download Jellyfin Tizen (this) repository.
   ```sh
   git clone https://github.com/jellyfin/jellyfin-tizen.git
   ```

### Build Jellyfin Web

```sh
cd jellyfin-web
npm ci --no-audit
USE_SYSTEM_FONTS=1 npm run build:production
```

> You should get `jellyfin-web/dist/` directory.

> `USE_SYSTEM_FONTS=1` is required to discard unused fonts and to reduce the size of the app. (Since Jellyfin Web 10.9)

> Use `npm run build:development` if you want to debug the app.

If any changes are made to `jellyfin-web/`, the `jellyfin-web/dist/` directory will need to be rebuilt using the command above.

### Prepare Interface

```sh
cd jellyfin-tizen
JELLYFIN_WEB_DIR=../jellyfin-web/dist npm ci --no-audit
```

> You should get `jellyfin-tizen/www/` directory.

> The `JELLYFIN_WEB_DIR` environment variable can be used to override the location of `jellyfin-web`.

> Add `DISCARD_UNUSED_FONTS=1` environment variable to discard unused fonts and to reduce the size of the app. (Until Jellyfin Web 10.9)  
> Don't use it with Jellyfin Web 10.9+. Instead, use `USE_SYSTEM_FONTS=1` environment variable when building Jellyfin Web.

If any changes are made to `jellyfin-web/dist/`, the `jellyfin-tizen/www/` directory will need to be rebuilt using the command above.

### Build WGT

> Make sure you select the appropriate Certificate Profile in Tizen Certificate Manager. This determines which devices you can install the widget on.

```sh
tizen build-web -e ".*" -e gulpfile.babel.js -e README.md -e "node_modules/*" -e "package*.json" -e "yarn.lock"
tizen package -t wgt -o . -- .buildResult
```

> You should get `Jellyfin.wgt`.

## Deployment

### Deploy to Emulator

1. Run emulator.
2. Install package.
   ```sh
   tizen install -n Jellyfin.wgt -t T-samsung-5.5-x86
   ```
   > Specify target with `-t` option. Use `sdb devices` to list them.

### Deploy to TV

1. Run TV.
2. Activate Developer Mode on TV. See [Enable Developer Mode on the TV](https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/tv-device.html#Connecting-the-TV-and-SDK).
3. Connect to TV with one of the following options:
   * Device Manager from `Tools -> Device Manager` in Tizen Studio.

   * sdb:
      ```sh
      sdb connect YOUR_TV_IP
      ```
4. If you are using a Samsung certificate, allow installs onto your TV using your certificate with one of the following options:
   > If you need to change or create a new Samsung certificate (see [Getting-Started](#getting-started) step 3), you will need to [re-build WGT](#build-wgt) once you have the Samsung certificate you'll use for the install.

   * Device Manager from `Tools -> Device Manager` in Tizen Studio:
      * Right-click on the connected device, and select `Permit to install applications`.

   * Tizen CLI:
      ```sh
      tizen install-permit -t UE65NU7400
      ```
      > Specify target with `-t` option. Use `sdb devices` to list them.

   * sdb:
      ```sh
      sdb push ~/SamsungCertificate/<PROFILE_NAME>/*.xml /home/developer
      ```
5. Install package.
   ```sh
   tizen install -n Jellyfin.wgt -t UE65NU7400
   ```
   > Specify target with `-t` option. Use `sdb devices` to list them.
