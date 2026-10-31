#!/usr/bin/env bash
set -euo pipefail

# Fast Provisioning Profile & Re-sign script for Wgram
# Re-signs existing Wgram.ipa with a newly requested Apple profile without recompiling!

BUNDLE_ID="com.amymusic.app"
TEAM_ID="M5LW4HM9AJ"
DEVICE_UDID="978FC836-2C9A-5441-BAD4-8DA70CE51C95"
IPA_PATH="$HOME/Desktop/Wgram.ipa"
SIGN_IDENTITY="Apple Development: a657eo@icloud.com (DDT93P97VB)"

echo "========================================="
echo "🔄 1/4 Запрос свежего Provisioning Profile от Apple..."
echo "========================================="
PROFILE_TMP="/tmp/ProfileRenew"
mkdir -p "$PROFILE_TMP"
cat << 'EOF' > "$PROFILE_TMP/project.yml"
name: ProfileRenew
options:
  bundleIdPrefix: com.amymusic
  deploymentTarget:
    iOS: "16.0"
settings:
  PRODUCT_BUNDLE_IDENTIFIER: com.amymusic.app
  DEVELOPMENT_TEAM: M5LW4HM9AJ
targets:
  ProfileRenew:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: Sources
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.amymusic.app
      DEVELOPMENT_TEAM: M5LW4HM9AJ
      CODE_SIGN_STYLE: Automatic
      GENERATE_INFOPLIST_FILE: YES
EOF

mkdir -p "$PROFILE_TMP/Sources"
cat << 'EOF' > "$PROFILE_TMP/Sources/main.swift"
import UIKit
print("Renew")
EOF

cd "$PROFILE_TMP"
xcodegen generate >/dev/null 2>&1 || true
xcodebuild -project ProfileRenew.xcodeproj -scheme ProfileRenew -destination "generic/platform=iOS" -allowProvisioningUpdates build >/dev/null 2>&1 || true

# Find newest profile for com.amymusic.app
PROFILES_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
LATEST_PROFILE=""
for f in "$PROFILES_DIR"/*.mobileprovision; do
    if security cms -D -i "$f" 2>/dev/null | grep -q "iOS Team Provisioning Profile: com.amymusic.app"; then
        if [ -z "$LATEST_PROFILE" ] || [ "$f" -nt "$LATEST_PROFILE" ]; then
            LATEST_PROFILE="$f"
        fi
    fi
done

if [ -z "$LATEST_PROFILE" ]; then
    echo "❌ Ошибка: Не удалось найти актуальный профиль!"
    exit 1
fi
echo "✅ Найден свежий профиль: $(basename "$LATEST_PROFILE")"

echo "========================================="
echo "📦 2/4 Переподписание $IPA_PATH..."
echo "========================================="
WORK_DIR=$(mktemp -d /tmp/wgram_resign.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

unzip -q "$IPA_PATH" -d "$WORK_DIR"
APP_DIR=$(find "$WORK_DIR/Payload" -maxdepth 1 -name "*.app")

# Extract entitlements from profile
security cms -D -i "$LATEST_PROFILE" > "$WORK_DIR/profile.plist"
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" "$WORK_DIR/profile.plist" > "$WORK_DIR/entitlements.plist"

# Replace embedded profile
cp -f "$LATEST_PROFILE" "$APP_DIR/embedded.mobileprovision"

# Re-sign frameworks and app
find "$APP_DIR/Frameworks" -type d -name "*.framework" 2>/dev/null | while read -r fw; do
    codesign -f -s "$SIGN_IDENTITY" --timestamp=none "$fw" 2>/dev/null || true
done

codesign -f -s "$SIGN_IDENTITY" --entitlements "$WORK_DIR/entitlements.plist" --timestamp=none "$APP_DIR"

# Repackage IPA
cd "$WORK_DIR"
zip -qry "$IPA_PATH" Payload

echo "✅ IPA успешно переподписан!"

echo "========================================="
echo "📱 3/4 Установка на iPhone..."
echo "========================================="
if xcrun devicectl list devices | grep -q "$DEVICE_UDID"; then
    echo "Устанавливаем..."
    xcrun devicectl device install app --device "$DEVICE_UDID" "$IPA_PATH"
    echo "Запускаем Wgram..."
    xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" || true
    echo "========================================="
    echo "🎉 Wgram обновлен и запущен за несколько секунд!"
    echo "========================================="
else
    echo "⚠️ Устройство не найдено в devicectl."
fi
