#!/usr/bin/env bash
set -euo pipefail

# Configuration
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA_SRC="$REPO_DIR/bazel-bin/Telegram/Telegram.ipa"
IPA_DEST="$HOME/Desktop/Wgram.ipa"
GDRIVE_FILE_ID="11GEFH0xSJ2VNZ_t571BLWh30T3MlkSs2"
DEVICE_UDID="978FC836-2C9A-5441-BAD4-8DA70CE51C95"
BUNDLE_ID="com.amymusic.app"

echo "========================================="
echo "🚀 1/4 Сборка Wgram (debug_arm64)..."
echo "========================================="
cd "$REPO_DIR"
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
python3 build-system/Make/Make.py \
    --overrideXcodeVersion \
    --cacheDir="$HOME/telegram-bazel-cache" \
    build \
    --buildNumber=1 \
    --configurationPath=build-system/development_configuration.json \
    --xcodeManagedCodesigning \
    --configuration debug_arm64

echo "========================================="
echo "📦 2/4 Копирование на Рабочий стол..."
echo "========================================="
cp -f "$IPA_SRC" "$IPA_DEST"
echo "Скопировано: $IPA_DEST ($(du -h "$IPA_DEST" | cut -f1))"

echo "========================================="
echo "📱 3/4 Установка на iPhone..."
echo "========================================="
if xcrun devicectl list devices | grep -q "$DEVICE_UDID"; then
    echo "Устройство найдено, устанавливаем..."
    xcrun devicectl device install app --device "$DEVICE_UDID" "$IPA_DEST" || true
    echo "Запуск Wgram..."
    xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" || true
else
    echo "Устройство не найдено в devicectl, пропускаем установку на телефон."
fi

echo "========================================="
echo "✅ Готово! Wgram собран и установлен."
echo "========================================="

