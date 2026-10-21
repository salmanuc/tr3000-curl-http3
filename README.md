# curl with HTTP/3 for Cudy TR3000

Build and install a custom version of **curl with HTTP/3 support** for the Cudy TR3000 running OpenWrt/ImmortalWrt 25.12.x.

This repository uses GitHub Actions to cross-compile curl and its required libraries for the MediaTek Filogic platform. A local Linux build machine is not required.

## Features

- **HTTP/3 support** using curl's QUIC transport dependencies.
- HTTP/2 support, where enabled by the build configuration.
- Cross-compilation for the Cudy TR3000's target architecture.
- Automated builds through GitHub Actions.
- APK packages published as downloadable build artifacts and GitHub Releases.

## Target platform

| Property | Value |
|---|---|
| Router | Cudy TR3000 |
| OpenWrt target | `mediatek/filogic` |
| Architecture | `aarch64_cortex-a53` |
| Build SDK | OpenWrt 25.12.6 |
| curl version | 8.23.0 |
| Package format | APK |

**Compatibility warning:** Packages built with the OpenWrt 25.12.6 SDK are not guaranteed to work on every ImmortalWrt 25.12.x installation. Check the router's firmware version, package dependencies, kernel requirements, and library ABI compatibility before installing.

## Repository contents

```text
tr3000-curl-http3/
├── .github/
│   └── workflows/
│       └── build.yml
├── curl/
│   ├── Makefile
│   └── Config.in
├── build-curl-http3-tr3000.sh
└── README.md
```

- `build-curl-http3-tr3000.sh` — downloads the SDK, configures the build, compiles the packages, and collects the resulting APK files.
- `curl/Makefile` — defines the curl and libcurl packages and their build options.
- `curl/Config.in` — defines the curl configuration options used by the package.
- `.github/workflows/build.yml` — automates the build and publishes its outputs.

## Build using GitHub Actions

1. Open the [Actions tab](https://github.com/salmanuc/tr3000-curl-http3/actions).
2. Select **Build curl with HTTP3 for Cudy TR3000**.
3. Click **Run workflow** and select the `main` branch.
4. Wait for the workflow to finish.
5. Open the completed run to download its APK artifact, or visit [Releases](https://github.com/salmanuc/tr3000-curl-http3/releases).

The build can take some time because it needs to download the SDK and compile curl and its dependencies.

### Build outputs

Depending on the selected build configuration, the output may include:

- `curl-*.apk` — curl command-line client.
- `libcurl4-*.apk` — libcurl shared library.
- `libngtcp2-*.apk` — QUIC transport library.
- `libnghttp3-*.apk` — HTTP/3 protocol library.
- `libopenssl3-*.apk` — OpenSSL library.

Only install packages actually produced by the build. Package names and versions may change between builds.

## Install on the router

Connect to the router over SSH:

```sh
ssh root@<router-ip>
```


```sh
cd /tmp

wget -O libopenssl3-3.5.9-r1.apk \
  https://github.com/salmanuc/tr3000-curl-http3/releases/download/curl-http3-build-4/libopenssl3-3.5.9-r1.apk

wget -O libngtcp2-1.15.0-r1.apk \
  https://github.com/salmanuc/tr3000-curl-http3/releases/download/curl-http3-build-4/libngtcp2-1.15.0-r1.apk

wget -O libnghttp3-1.11.0-r1.apk \
  https://github.com/salmanuc/tr3000-curl-http3/releases/download/curl-http3-build-4/libnghttp3-1.11.0-r1.apk

wget -O libcurl4-8.23.0-r1.apk \
  https://github.com/salmanuc/tr3000-curl-http3/releases/download/curl-http3-build-4/libcurl4-8.23.0-r1.apk

wget -O curl-8.23.0-r1.apk \
  https://github.com/salmanuc/tr3000-curl-http3/releases/download/curl-http3-build-4/curl-8.23.0-r1.apk

apk add --allow-untrusted \
  ./libopenssl3-3.5.9-r1.apk \
  ./libngtcp2-1.15.0-r1.apk \
  ./libnghttp3-1.11.0-r1.apk \
  ./libcurl4-8.23.0-r1.apk \
  ./curl-8.23.0-r1.apk
```






**Important:** `--allow-untrusted` permits installation of locally supplied APKs without trusted package signatures. It does not make incompatible packages safe or resolve missing dependencies. Review the package provenance and compatibility before proceeding.

## Verify HTTP/3 support

Check curl's compiled features:

```sh
curl -V
```

Look for `HTTP3` in the `Features` list.

Then test an HTTP/3 request against a server that supports HTTP/3:

```sh
curl --http3 -I https://cloudflare-quic.com
```

If the test fails, check the error output, network connectivity, DNS resolution, QUIC/UDP connectivity, and whether HTTP/3 is enabled in the compiled curl binary.

## Updating curl

To build a newer version:

1. Update `PKG_VERSION` in `curl/Makefile`.
2. Ensure the corresponding source archive is available.
3. Verify the source archive and its integrity.
4. Check that the package configuration and HTTP/3 dependencies remain compatible with that curl version.
5. Run a new GitHub Actions build.
6. Test the resulting packages before deploying them to the router.

The source hash should be verified against a trusted checksum or release signature. Calculating a hash from the same downloaded file provides an integrity value for the build but does not independently authenticate the source.


## Disclaimer

This project provides custom-built packages for a specific router target. Use at your own risk. Keep a backup of your router configuration and retain a recovery method before installing custom packages.

## Links

- [Repository](https://github.com/salmanuc/tr3000-curl-http3)
- [GitHub Actions](https://github.com/salmanuc/tr3000-curl-http3/actions)
- [Releases](https://github.com/salmanuc/tr3000-curl-http3/releases)
- [Official curl website](https://curl.se/)
- [OpenWrt downloads](https://downloads.openwrt.org/)


## Acknowledgements & Credits

This project builds on the work of the following projects and contributors:

- **[sbwml](https://github.com/sbwml)** — for the OpenWrt curl HTTP/3/QUIC build work and package implementation that inspired this project.
- **[OpenWrt](https://github.com/openwrt/openwrt)** — for the build system, SDK, cross-compilation toolchain, and firmware packaging infrastructure.
- **[OpenWrt packages](https://github.com/openwrt/packages)** — for the upstream curl package framework and dependency definitions.
- **[curl](https://github.com/curl/curl)** — for the curl command-line tool and libcurl, including HTTP/3 support.
- **[ngtcp2](https://github.com/ngtcp2/ngtcp2)** — for the QUIC transport implementation.
- **[nghttp3](https://github.com/ngtcp2/nghttp3)** — for the HTTP/3 protocol implementation.
- **[OpenSSL](https://github.com/openssl/openssl)** — for TLS and cryptographic functionality used by the build.

This repository automates a target-specific build for the Cudy TR3000. It is not an official OpenWrt, curl, or sbwml project. Please refer to the upstream repositories for their respective licenses and attribution requirements.

All trademarks and project names belong to their respective owners.

