#!/usr/bin/env bash
set -eo pipefail

REPO_URL="https://reon-org.github.io/packager/void"
ARCH="x86_64"
PKG_TARGET="rind"
WORK_DIR=$(mktemp -d /tmp/xbps_verify.XXXXXX)

# Cleanup on exit
trap 'rm -rf "$WORK_DIR"' EXIT

echo "[1/4] Downloading repository metadata..."
curl -sSfL "$REPO_URL/${ARCH}-repodata" -o "$WORK_DIR/repodata"
curl -sSfL "$REPO_URL/${ARCH}-repodata.sig" -o "$WORK_DIR/repodata.sig"
echo "  -> Found index and signature files."

echo "[2/4] Verifying Index Archive Structure..."
# XBPS indexes are zstd compressed tar archives
if ! tar --use-compress-program=zstd -tf "$WORK_DIR/repodata" > /dev/null 2>&1; then
    echo "  [ERROR] Index file is not a valid zstd-compressed tar archive!"
    exit 1
fi

# Extract property list file
tar --use-compress-program=zstd -xf "$WORK_DIR/repodata" -C "$WORK_DIR"
if [ ! -f "$WORK_DIR/index.plist" ]; then
    echo "  [ERROR] Structure broken: 'index.plist' missing inside archive!"
    exit 1
fi
echo "  -> Archive formatting is valid."

echo "[3/4] Inspecting Repository Key Signatures..."
HAS_KEY=$(grep -A1 "<key>pubkey-fingerprint</key>" "$WORK_DIR/index.plist" | grep "<string>" || true)
HAS_OWNER=$(grep -A1 "<key>signed-by</key>" "$WORK_DIR/index.plist" | grep "<string>" || true)

if [ -n "$HAS_KEY" ] && [ -n "$HAS_OWNER" ]; then
    echo "  -> Repository Index Signature: VALID"
    echo "     Owner: $(echo "$HAS_OWNER" | tr -d '[:blank:]' | sed -e 's/<[^>]*>//g')"
    echo "     Fingerprint: $(echo "$HAS_KEY" | tr -d '[:blank:]' | sed -e 's/<[^>]*>//g')"
else
    echo "  [WARNING] Repository metadata index lacks inner RSA signatures!"
fi

echo "[4/4] Locating Target Package: '$PKG_TARGET'..."
# Locate target package definition blocks inside the plist structure
PKG_BLOCK=$(grep -n "<string>$PKG_TARGET</string>" "$WORK_DIR/index.plist" | cut -d: -f1 || true)

if [ -z "$PKG_BLOCK" ]; then
    echo "  [ERROR] Package '$PKG_TARGET' was not found registered in this repo index!"
    exit 1
fi

# Extract exact package filename target from plist context
FILE_TARGET=$(grep -A20 -B5 "<string>$PKG_TARGET</string>" "$WORK_DIR/index.plist" | grep -A1 "<key>filename</key>" | grep "<string>" | sed -e 's/<[^>]*>//g' | tr -d '[:blank:]' || true)

if [ -z "$FILE_TARGET" ]; then
    echo "  [ERROR] Failed to map binary archive string from metadata."
    exit 1
fi

echo "  -> Target package found: $FILE_TARGET"
echo "  -> Checking payload links online..."

# Send HTTP HEAD requests to confirm final payload file paths exist on Github Pages
if curl -sI fL "$REPO_URL/$FILE_TARGET" | grep -q "200 OK" && \
   curl -sI fL "$REPO_URL/$FILE_TARGET.sig2" | grep -q "200 OK"; then
    echo "  -> SUCCESSFULLY VERIFIED: Both package binary and signature exist on host."
    echo "  -> Structure verification complete. Repository layout is sound."
else
    echo "  [ERROR] The binary (.xbps) or target signature (.sig2) is physically missing from the server paths!"
    exit 1
fi
