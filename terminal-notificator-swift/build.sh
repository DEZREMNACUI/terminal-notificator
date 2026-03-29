#!/bin/bash
set -e

# 解析参数
APP_NAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --app)
            APP_NAME="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# 确定输出目录和配置
if [ -z "$APP_NAME" ]; then
    OUTPUT_DIR="apps/default"
    BUNDLE_ID="com.terminal-notificator.default"
    DISPLAY_NAME="Terminal Notificator"
else
    OUTPUT_DIR="apps/$APP_NAME"
    BUNDLE_ID="com.terminal-notificator.$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    DISPLAY_NAME="Terminal Notificator ($APP_NAME)"
fi

# 1. 构建 CLI 二进制
echo "Building CLI binary..."
swift build -c release

# 2. 创建 .app 结构
echo "Creating .app bundle structure at $OUTPUT_DIR..."
rm -rf "$OUTPUT_DIR/TerminalNotificator.app"
mkdir -p "$OUTPUT_DIR/TerminalNotificator.app/Contents/MacOS"
mkdir -p "$OUTPUT_DIR/TerminalNotificator.app/Contents/Resources"

# 3. 复制二进制
echo "Copying binary..."
cp .build/release/TerminalNotificator "$OUTPUT_DIR/TerminalNotificator.app/Contents/MacOS/"

# 4. 获取并复制图标（如果指定了应用名）
if [ -n "$APP_NAME" ]; then
    echo "Extracting icon from $APP_NAME..."

    # 查找应用路径（多种方法尝试）
    APP_PATH=""

    # 方法 1: 通过 AppleScript 查找
    APP_PATH=$(osascript -e 'tell application "System Events" to get POSIX path of (file of application process "'"$APP_NAME"'" as alias)' 2>/dev/null || true)

    # 方法 2: 通过 mdfind 查找（备用）
    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        APP_PATH=$(mdfind "kMDItemKind == 'Application' && kMDItemDisplayName == '$APP_NAME'" 2>/dev/null | head -1 || true)
    fi

    # 方法 3: 尝试在 /Applications 中查找
    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        for ext in ".app" ""; do
            if [ -d "/Applications/$APP_NAME$ext" ]; then
                APP_PATH="/Applications/$APP_NAME$ext"
                break
            fi
        done
    fi

    if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
        echo "Found application at: $APP_PATH"

        # 获取图标文件名
        ICON_NAME=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleIconFile 2>/dev/null || true)

        if [ -n "$ICON_NAME" ]; then
            # 去掉可能的 .icns 后缀
            ICON_NAME="${ICON_NAME%.icns}"

            # 尝试复制图标文件
            if [ -f "$APP_PATH/Contents/Resources/$ICON_NAME.icns" ]; then
                cp "$APP_PATH/Contents/Resources/$ICON_NAME.icns" "$OUTPUT_DIR/TerminalNotificator.app/Contents/Resources/AppIcon.icns"
                echo "Icon copied successfully: $ICON_NAME.icns"
            else
                echo "Warning: Icon file not found at $APP_PATH/Contents/Resources/$ICON_NAME.icns"
            fi
        else
            echo "Warning: CFBundleIconFile not found in Info.plist"
        fi
    else
        echo "Warning: Application '$APP_NAME' not found, creating .app without custom icon"
    fi
fi

# 5. 生成 Info.plist
echo "Generating Info.plist..."

# 检查是否有自定义图标
ICON_ENTRY=""
if [ -f "$OUTPUT_DIR/TerminalNotificator.app/Contents/Resources/AppIcon.icns" ]; then
    ICON_ENTRY="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
fi

cat > "$OUTPUT_DIR/TerminalNotificator.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
$ICON_ENTRY
</dict>
</plist>
EOF

# 6. 注册和签名
echo "Registering and signing app bundle..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$OUTPUT_DIR/TerminalNotificator.app" 2>/dev/null
codesign --force --deep --sign - "$OUTPUT_DIR/TerminalNotificator.app" 2>/dev/null

echo ""
echo "Build complete!"
echo "App bundle: $OUTPUT_DIR/TerminalNotificator.app"
echo ""
echo "Usage:"
echo "  $OUTPUT_DIR/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --title \"Test\" --message \"Hello\""
