#!/bin/bash
set -e

# 1. 构建 CLI 二进制
echo "Building CLI binary..."
swift build -c release

# 2. 创建 .app 结构
APP_NAME="TerminalNotificator.app"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME"

echo "Creating .app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 3. 复制二进制
echo "Copying binary..."
cp "$BUILD_DIR/TerminalNotificator" "$APP_DIR/Contents/MacOS/"

# 4. 生成 Info.plist
echo "Generating Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.terminal-notificator.app</string>
    <key>CFBundleName</key>
    <string>Terminal Notificator</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
EOF

echo ""
echo "Build complete!"
echo "App bundle: $APP_DIR"
echo ""
echo "Usage:"
echo "  $APP_DIR/Contents/MacOS/TerminalNotificator --title \"Test\" --message \"Hello\""
