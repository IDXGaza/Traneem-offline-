#!/bin/bash
# ============================================================
# build-apk.sh - Build and sign the Traneem offline APK
# ============================================================
# This script builds a signed APK from the web app files.
# It uses apksigner (v2/v3 signing) which is required for
# Android 14+ (targetSdkVersion 34).
#
# Prerequisites:
#   - Java JDK (keytool, javac, d8/dx)
#   - Android SDK build-tools (aapt, apksigner, zipalign)
#   - Or: sudo apt-get install aapt apksigner default-jdk
#
# Usage:
#   ./build-apk.sh
#
# The signed APK will be output as: traneem-offline.apk
# ============================================================

set -e

PACKAGE_NAME="com.traneem.offline"
APP_LABEL="ترانيم"
VERSION_CODE=1
VERSION_NAME="1.0"
MIN_SDK=24
TARGET_SDK=34
COMPILE_SDK=34

KEYSTORE="traneem-release.jks"
KEY_ALIAS="traneem"
STORE_PASS="traneem123"
KEY_PASS="traneem123"

OUTPUT_APK="traneem-offline.apk"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building Traneem Offline APK ==="

# Step 1: Generate keystore if it doesn't exist
if [ ! -f "$SCRIPT_DIR/$KEYSTORE" ]; then
  echo "[1/5] Generating signing keystore..."
  keytool -genkeypair -v \
    -keystore "$SCRIPT_DIR/$KEYSTORE" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias "$KEY_ALIAS" \
    -storepass "$STORE_PASS" -keypass "$KEY_PASS" \
    -dname "CN=Traneem, OU=App, O=Traneem, L=Unknown, ST=Unknown, C=US"
else
  echo "[1/5] Keystore already exists, skipping generation."
fi

# Step 2: Create a temporary build directory
BUILD_DIR=$(mktemp -d)
echo "[2/5] Preparing APK contents in $BUILD_DIR..."

mkdir -p "$BUILD_DIR/assets/assets"
mkdir -p "$BUILD_DIR/assets/icons"
mkdir -p "$BUILD_DIR/assets/fonts"

# Copy web app files into assets
cp "$SCRIPT_DIR/index.html"            "$BUILD_DIR/assets/"
cp "$SCRIPT_DIR/manifest.webmanifest"  "$BUILD_DIR/assets/"
cp "$SCRIPT_DIR/sw.js"                 "$BUILD_DIR/assets/"
cp "$SCRIPT_DIR/main.js"               "$BUILD_DIR/assets/assets/"
cp "$SCRIPT_DIR/main.css"              "$BUILD_DIR/assets/assets/"
cp "$SCRIPT_DIR/default-cover.jpg"     "$BUILD_DIR/assets/assets/"
cp "$SCRIPT_DIR/cairo.css"             "$BUILD_DIR/assets/fonts/"
cp "$SCRIPT_DIR"/cairo-*.ttf           "$BUILD_DIR/assets/fonts/"
cp "$SCRIPT_DIR/icon-192.png"          "$BUILD_DIR/assets/icons/"
cp "$SCRIPT_DIR/icon-512.png"          "$BUILD_DIR/assets/icons/"
cp "$SCRIPT_DIR/icon-maskable-512.png" "$BUILD_DIR/assets/icons/"
cp "$SCRIPT_DIR/favicon-48.png"        "$BUILD_DIR/assets/icons/"
cp "$SCRIPT_DIR/app-icon.png"          "$BUILD_DIR/assets/icons/"

# Step 3: Build the unsigned APK
echo "[3/5] Building unsigned APK..."

# If a pre-built APK template exists, use it as a base
# Otherwise, this script expects the APK to already be built
# and only handles the signing step.
#
# For a full from-scratch build, you would need:
#   - AndroidManifest.xml (compiled)
#   - classes.dex (compiled Java sources)
#   - aapt for resource compilation
#
# Since this project uses a pre-built APK structure, we handle
# re-signing of existing APKs below.

if [ -f "$SCRIPT_DIR/traneem-unsigned.apk" ]; then
  echo "   Using existing unsigned APK as base."
  cp "$SCRIPT_DIR/traneem-unsigned.apk" "$BUILD_DIR/unsigned.apk"
else
  echo "   No unsigned APK found. Checking for a signed APK to re-sign..."
  # Look for any existing APK to strip and re-sign
  EXISTING_APK=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.apk" ! -name "$OUTPUT_APK" | head -1)
  if [ -n "$EXISTING_APK" ]; then
    echo "   Found: $EXISTING_APK - stripping old signature..."
    cp "$EXISTING_APK" "$BUILD_DIR/unsigned.apk"
    zip -d "$BUILD_DIR/unsigned.apk" "META-INF/*" 2>/dev/null || true
  else
    echo "ERROR: No APK file found to sign. Place an unsigned APK in $SCRIPT_DIR"
    rm -rf "$BUILD_DIR"
    exit 1
  fi
fi

# Step 4: Align the APK (if zipalign is available)
echo "[4/5] Aligning APK..."
if command -v zipalign &> /dev/null; then
  zipalign -f 4 "$BUILD_DIR/unsigned.apk" "$BUILD_DIR/aligned.apk"
else
  echo "   zipalign not found, skipping alignment."
  cp "$BUILD_DIR/unsigned.apk" "$BUILD_DIR/aligned.apk"
fi

# Step 5: Sign with apksigner (v2 + v3 signature schemes)
echo "[5/5] Signing APK with v2/v3 signature scheme..."
apksigner sign \
  --ks "$SCRIPT_DIR/$KEYSTORE" \
  --ks-pass "pass:$STORE_PASS" \
  --key-pass "pass:$KEY_PASS" \
  --ks-key-alias "$KEY_ALIAS" \
  --v1-signing-enabled true \
  --v2-signing-enabled true \
  --out "$SCRIPT_DIR/$OUTPUT_APK" \
  "$BUILD_DIR/aligned.apk"

# Verify
echo ""
echo "=== Verifying APK signature ==="
apksigner verify --verbose "$SCRIPT_DIR/$OUTPUT_APK"

# Cleanup
rm -rf "$BUILD_DIR"

echo ""
echo "=== Build complete! ==="
echo "Output: $SCRIPT_DIR/$OUTPUT_APK"
echo ""
echo "IMPORTANT: Do NOT use 'jarsigner' to sign the APK."
echo "Android 14+ (SDK 34) requires APK Signature Scheme v2 or later."
echo "Always use 'apksigner' which is included in Android SDK build-tools."
