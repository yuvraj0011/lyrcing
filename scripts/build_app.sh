#!/bin/zsh
# Builds Lyrcing.app and Lyrcing.dmg into ./dist
set -euo pipefail
cd "$(dirname "$0")/.."
APP=dist/Lyrcing.app
rm -rf dist && mkdir -p $APP/Contents/{MacOS,Resources}

swift build -c release
cp "$(swift build -c release --show-bin-path)/Lyrcing" $APP/Contents/MacOS/Lyrcing

cp Resources/emoji_index.json $APP/Contents/Resources/

# Icon
ICONSET=dist/AppIcon.iconset; mkdir -p $ICONSET
swiftc -o dist/icon scripts/icon.swift && dist/icon dist/icon1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s dist/icon1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) dist/icon1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o $APP/Contents/Resources/AppIcon.icns
rm -rf $ICONSET dist/icon dist/icon1024.png

cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Lyrcing</string>
  <key>CFBundleDisplayName</key><string>Lyrcing</string>
  <key>CFBundleIdentifier</key><string>com.yuvraj.lyrcing</string>
  <key>CFBundleExecutable</key><string>Lyrcing</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSScreenCaptureUsageDescription</key><string>Lyrcing listens to your Mac's audio output to sync effects to the beat. No screen content is used.</string>
  <key>NSAppleEventsUsageDescription</key><string>Lyrcing reads the current song from Apple Music or Spotify to show synced lyrics.</string>
</dict></plist>
PLIST

codesign --force --deep --sign - $APP

# DMG with Applications shortcut
STAGE=dist/dmg; mkdir -p $STAGE && cp -R $APP $STAGE/ && ln -s /Applications $STAGE/Applications
hdiutil create -volname "Lyrcing" -srcfolder $STAGE -ov -format UDZO dist/Lyrcing.dmg >/dev/null
rm -rf $STAGE
echo "Built $(pwd)/dist/Lyrcing.dmg"
