#!/bin/bash

APK_SRC="android/app/build/outputs/apk/debug/app-debug.apk"
APK_DEST="build/app/outputs/flutter-apk/app-debug.apk"

mkdir -p "$(dirname "$APK_DEST")"
cp "$APK_SRC" "$APK_DEST"

echo "✅ APK copiado correctamente a: $APK_DEST"

#flutter clean            
#flutter build apk --debug
#./copy-apk.sh
#flutter run