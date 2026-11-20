#!/usr/bin/env bash
# ==============================================================================
# CineLog Pro - iPhone 14 Pro Max Apple Log & Cinema RAW Camera Builder
# Author: Kaushal Labana
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
BUILD_DIR="${PROJECT_DIR}/build"
OUTPUT_DIR="${PROJECT_DIR}/output"
IPA_NAME="CineLog-Pro-v1.0.0-iPhone14ProMax.ipa"

echo "===================================================================="
echo "🎥 CineLog Pro - iOS 10-Bit Apple Log & RAW Camera App Builder"
echo "Target Device: iPhone 14 Pro Max (Sony IMX803 48MP / A16 Bionic)"
echo "Pipeline: Metal Compute + 10-bit Bypass -> ProRes 422HQ & CinemaDNG"
echo "===================================================================="

mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

if command -v xcodebuild >/dev/null 2>&1; then
    echo "⚙️ Building with xcodebuild for iPhoneOS..."
    xcodebuild build \
        -project "${PROJECT_DIR}/CineLog.xcodeproj" \
        -scheme "CineLog" \
        -configuration "Release" \
        -sdk "iphoneos" \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
    
    APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Release-iphoneos/CineLog.app"
    
    if [ -d "${APP_PATH}" ]; then
        echo "📦 Packaging IPA for sideloading (AltStore / Sideloadly / Scarlet)..."
        PAYLOAD_DIR="${BUILD_DIR}/Payload"
        rm -rf "${PAYLOAD_DIR}"
        mkdir -p "${PAYLOAD_DIR}"
        cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"
        
        cd "${BUILD_DIR}"
        zip -r -q "${OUTPUT_DIR}/${IPA_NAME}" Payload
        cd "${SCRIPT_DIR}"
        
        echo ""
        echo "✅ SUCCESS! IPA created at:"
        echo "   ${OUTPUT_DIR}/${IPA_NAME}"
        echo ""
        echo "📲 How to install on your iPhone 14 Pro Max:"
        echo "   1. Connect iPhone to Mac / PC with USB cable."
        echo "   2. Open Sideloadly (or AltStore / TrollStore)."
        echo "   3. Drag '${OUTPUT_DIR}/${IPA_NAME}' into Sideloadly."
        echo "   4. Enter your Apple ID to sign and install."
        echo "   5. On iPhone, go to Settings -> General -> VPN & Device Management -> Trust Certificate."
        echo "   6. Launch 'CineLog Pro' and enjoy 10-bit Apple Log & Cinema RAW recording!"
    else
        echo "❌ Error: CineLog.app was not found after build."
        exit 1
    fi
else
    echo "ℹ️  xcodebuild is not present in this environment (Linux sandbox)."
    echo "    All source files, Metal shaders, Color Math, and Xcode project have been generated."
    echo "    Run this command script directly on your Mac or open CineLog.xcodeproj in Xcode!"
fi
