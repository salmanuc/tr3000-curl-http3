#!/usr/bin/env bash
# Build curl (+libcurl) with HTTP/3 for Cudy TR3000 on OpenWrt 25.12.6
# Target: mediatek/filogic, arch: aarch64_cortex-a53
#
# Uses the OpenWrt SDK (prebuilt toolchain) so you only compile this one
# package tree instead of a full firmware image.
#
# Run this on a Linux x86_64 build machine (a VM/container is fine).
#
# v2 changes based on a working build:
#  - Config uses LIBCURL_NGTCP2 (not LIBCURL_OPENSSL_QUIC — curl 8.21's
#    configure rejects nghttp3+openssl-quic without ngtcp2 present)
#  - Dropped the nonexistent CONFIG_LIBCURL_HTTP3 symbol (this feed
#    doesn't define it; it was silently ignored)
#  - Package collection now also searches bin/packages/$ARCH/base,
#    since libopenssl3 is built there, not under .../packages
#  - Fixed the find command's -o grouping so -maxdepth actually applies
#    to every clause, not just the first
#  - Temporarily removes uboot-mediatek from the feed tree so the
#    prereq scan doesn't grind through dozens of unrelated board profiles

set -euo pipefail

RELEASE="25.12.6"
TARGET="mediatek"
SUBTARGET="filogic"
ARCH="aarch64_cortex-a53"
WORKDIR="$HOME/tr3000-curl-http3"

mkdir -p "$WORKDIR" && cd "$WORKDIR"

# ---------------------------------------------------------------------------
# 1. Find and fetch the matching SDK tarball
# ---------------------------------------------------------------------------
SDK_INDEX="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/${SUBTARGET}/"
echo "==> Looking up SDK filename from ${SDK_INDEX}"
SDK_FILE=$(curl -fsSL "$SDK_INDEX" | grep -oE "openwrt-sdk-${RELEASE}-${TARGET}-${SUBTARGET}_[^\"]*\.tar\.zst" | head -n1)

if [ -z "$SDK_FILE" ]; then
  echo "Could not auto-detect SDK filename. Open $SDK_INDEX in a browser,"
  echo "grab the openwrt-sdk-*.tar.zst filename, and set SDK_FILE manually."
  exit 1
fi

echo "==> SDK: $SDK_FILE"
if [ ! -f "$SDK_FILE" ]; then
  wget "${SDK_INDEX}${SDK_FILE}"
fi

# ---------------------------------------------------------------------------
# 2. Extract SDK
# ---------------------------------------------------------------------------
SDK_DIR="${SDK_FILE%.tar.zst}"
if [ ! -d "$SDK_DIR" ]; then
  echo "==> Extracting SDK"
  tar --use-compress-program=unzstd -xf "$SDK_FILE"
fi
cd "$SDK_DIR"

# ---------------------------------------------------------------------------
# 3. Set up feeds (pulls in official packages feed as a baseline), then
#    override net/curl with the sbwml feed you linked
# ---------------------------------------------------------------------------
echo "==> Updating and installing feeds"
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> Installing custom curl package from this repository"

# Remove sbwml's curl package
rm -rf feeds/packages/net/curl

# Create the package directory
mkdir -p feeds/packages/net/curl

# Copy our custom Makefile
REPO_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"
cp "$REPO_DIR/curl/Makefile" feeds/packages/net/curl/Makefile
cp "$REPO_DIR/curl/Config.in" feeds/packages/net/curl/Config.in

# Automatically calculate the SHA-256 hash for the selected curl version
echo "==> Calculating curl source hash"

CURL_VERSION=$(sed -n 's/^PKG_VERSION:=//p' feeds/packages/net/curl/Makefile)
CURL_ARCHIVE="curl-${CURL_VERSION}.tar.bz2"
CURL_URL="https://github.com/curl/curl/releases/download/curl-${CURL_VERSION//./_}/${CURL_ARCHIVE}"

curl -fL "$CURL_URL" -o "/tmp/$CURL_ARCHIVE"

CURL_HASH=$(sha256sum "/tmp/$CURL_ARCHIVE" | awk '{print $1}')

sed -i "s/^PKG_HASH:=.*/PKG_HASH:=$CURL_HASH/" feeds/packages/net/curl/Makefile

echo "curl version: $CURL_VERSION"
echo "SHA-256: $CURL_HASH"

# Register the custom package
./scripts/feeds install -f -p packages curl

# ---------------------------------------------------------------------------
# 3b. uboot-mediatek's prereq scan is slow and irrelevant to curl — pull it
#     out of the tree so `make prereq` doesn't grind through every board
#     profile before compiling starts. Safe: curl has no dependency on it.
# ---------------------------------------------------------------------------
if [ -d feeds/base_root/package/boot/uboot-mediatek ]; then
  echo "==> Temporarily removing uboot-mediatek (unrelated to curl, slows prereq scan)"
  mv feeds/base_root/package/boot/uboot-mediatek "/tmp/uboot-mediatek.bak.$$"
fi

# ---------------------------------------------------------------------------
# 4. Configure: curl with OpenSSL, HTTP2, and HTTP3 via nghttp3+ngtcp2
# ---------------------------------------------------------------------------
echo "==> Writing .config"
cat > .config <<'EOF'
CONFIG_ALL=n
CONFIG_TARGET_ROOTFS_INITRAMFS=n
CONFIG_PACKAGE_curl=y
CONFIG_LIBCURL_OPENSSL=y
CONFIG_LIBCURL_NGHTTP2=y
CONFIG_LIBCURL_ZLIB=y
CONFIG_LIBCURL_FTP=y
CONFIG_LIBCURL_MQTT=y
CONFIG_LIBCURL_COOKIES=y
CONFIG_LIBCURL_PROXY=y
CONFIG_LIBCURL_NGHTTP3=y
CONFIG_LIBCURL_NGTCP2=y
EOF

make defconfig

echo "==> Confirming HTTP3-related config landed correctly:"
grep -i "nghttp3\|ngtcp2\|openssl_quic" .config || true

echo "==> If you want to tweak curl's protocol/backend selection interactively:"
echo "    make menuconfig   # Network -> curl -> HTTP3/QUIC and SSL library submenu"
echo "    (skip this if the .config above already matches what you want)"

# ---------------------------------------------------------------------------
# 5. Build just curl and its dependency chain (openssl, libngtcp2,
#    libnghttp3, libcurl) — not a full image
# ---------------------------------------------------------------------------
echo "==> Building curl (this pulls in libngtcp2/libnghttp3/openssl deps)"
make package/curl/compile V=s -j"$(nproc)" IGNORE_ERRORS="n m"

# ---------------------------------------------------------------------------
# 6. Collect the resulting packages
#    NOTE: libopenssl3 is built under bin/packages/$ARCH/base, everything
#    else (curl, libcurl4, libngtcp2, libnghttp3) under .../packages
# ---------------------------------------------------------------------------
mkdir -p "$WORKDIR/output"

echo "==> Collecting built packages:"
find "bin/packages/${ARCH}" \
  \( -iname "*curl*" -o -iname "*ngtcp2*" -o -iname "*nghttp3*" -o -iname "*openssl*" \) \
  -type f -print

find "bin/packages/${ARCH}" \
  \( -iname "*curl*" -o -iname "*ngtcp2*" -o -iname "*nghttp3*" -o -iname "*openssl*" \) \
  -type f -exec cp {} "$WORKDIR/output/" \;

echo
echo "==> Done. Packages copied to: $WORKDIR/output"
ls -la "$WORKDIR/output"
echo
echo "Next, copy them to the router and install with apk (OpenWrt 25.12 uses apk, not opkg)."
echo "Install order matters — deps before curl itself:"
echo
echo "  scp $WORKDIR/output/*.apk root@<router-ip>:/tmp/"
echo "  ssh root@<router-ip>"
echo "  cd /tmp"
echo "  apk add --allow-untrusted ./libopenssl3-*.apk ./libngtcp2-*.apk ./libnghttp3-*.apk ./libcurl4-*.apk ./curl-*.apk"
echo
echo "Verify with:"
echo "  curl -V                                    # should list HTTP3 in Features"
echo "  curl --http3 https://cloudflare-quic.com -v # should show 'Connected ... (QUIC)'"
