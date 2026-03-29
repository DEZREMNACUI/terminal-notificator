# Dynamic App Bundle Creation Design

## 概述

扩展 `build.sh` 脚本，支持根据应用名称动态创建带有对应应用图标的 .app 包，使通知显示为该应用的图标。

## 背景

当前 terminal-notificator 创建的 .app 包使用默认图标，用户希望通知能显示为触发源应用（如 Zed、iTerm、Terminal）的图标，以便更容易识别通知来源。

## 设计目标

1. 支持通过应用名称创建带对应图标的 .app 包
2. 无参数时创建默认 .app 包
3. 所有产物统一存放在 `apps/` 目录下

## 命令行接口

```bash
# 无参数 - 创建默认 .app（无特定图标）
./build.sh
# 输出: apps/default/TerminalNotificator.app

# 指定应用名 - 创建带该应用图标的 .app
./build.sh --app "Zed"
# 输出: apps/Zed/TerminalNotificator.app

./build.sh --app "iTerm"
# 输出: apps/iTerm/TerminalNotificator.app
```

## 目录结构

```
terminal-notificator-swift/
├── build.sh
├── apps/
│   ├── default/
│   │   └── TerminalNotificator.app/    # 默认图标
│   ├── Zed/
│   │   └── TerminalNotificator.app/    # Zed 图标
│   ├── iTerm/
│   │   └── TerminalNotificator.app/    # iTerm 图标
│   └── Terminal/
│       └── TerminalNotificator.app/    # Terminal 图标
└── ...
```

## 图标获取逻辑

### 查找应用路径

```bash
# 方法 1: 通过 AppleScript 查找（优先）
APP_PATH=$(osascript -e 'tell application "System Events" to get POSIX path of (file of application process "'"$APP_NAME"'" as alias)' 2>/dev/null)

# 方法 2: 通过 mdfind 查找（备用）
APP_PATH=$(mdfind "kMDItemKind == 'Application' && kMDItemDisplayName == '$APP_NAME'" | head -1)
```

### 提取图标

macOS 应用图标通常位于 `App.app/Contents/Resources/` 目录下，文件格式为 `.icns`。

提取步骤：
1. 查找应用的 Info.plist 获取 `CFBundleIconFile` 属性
2. 从 `Contents/Resources/` 复制对应的 .icns 文件
3. 重命名为 `AppIcon.icns` 放入目标 .app 的 Resources 目录

```bash
# 获取图标文件名
ICON_NAME=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleIconFile 2>/dev/null)
# 去掉可能的 .icns 后缀
ICON_NAME="${ICON_NAME%.icns}"
# 复制图标
cp "$APP_PATH/Contents/Resources/$ICON_NAME.icns" "$OUTPUT_DIR/TerminalNotificator.app/Contents/Resources/AppIcon.icns"
```

## Info.plist 配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.terminal-notificator.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>Terminal Notificator ($APP_NAME)</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
```

**关键配置说明：**
- `CFBundleIdentifier` — 每个变体使用不同的 bundle ID，避免权限冲突
- `CFBundleIconFile` — 指向 Resources 目录下的图标文件

## build.sh 脚本结构

```bash
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

# 确定输出目录
if [ -z "$APP_NAME" ]; then
    OUTPUT_DIR="apps/default"
    BUNDLE_ID="com.terminal-notificator.default"
    DISPLAY_NAME="Terminal Notificator"
else
    OUTPUT_DIR="apps/$APP_NAME"
    BUNDLE_ID="com.terminal-notificator.$(echo $APP_NAME | tr '[:upper:]' '[:lower:]')"
    DISPLAY_NAME="Terminal Notificator ($APP_NAME)"
fi

# 1. 构建 CLI 二进制
echo "Building CLI binary..."
swift build -c release

# 2. 创建 .app 结构
echo "Creating .app bundle structure..."
rm -rf "$OUTPUT_DIR/TerminalNotificator.app"
mkdir -p "$OUTPUT_DIR/TerminalNotificator.app/Contents/MacOS"
mkdir -p "$OUTPUT_DIR/TerminalNotificator.app/Contents/Resources"

# 3. 复制二进制
echo "Copying binary..."
cp .build/release/TerminalNotificator "$OUTPUT_DIR/TerminalNotificator.app/Contents/MacOS/"

# 4. 获取并复制图标（如果指定了应用名）
if [ -n "$APP_NAME" ]; then
    echo "Extracting icon from $APP_NAME..."
    # 查找应用路径
    APP_PATH=$(osascript -e 'tell application "System Events" to get POSIX path of (file of application process "'"$APP_NAME"'" as alias)' 2>/dev/null || \
               mdfind "kMDItemKind == 'Application' && kMDItemDisplayName == '$APP_NAME'" | head -1)

    if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
        # 获取图标文件名
        ICON_NAME=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleIconFile 2>/dev/null)
        ICON_NAME="${ICON_NAME%.icns}"

        if [ -f "$APP_PATH/Contents/Resources/$ICON_NAME.icns" ]; then
            cp "$APP_PATH/Contents/Resources/$ICON_NAME.icns" "$OUTPUT_DIR/TerminalNotificator.app/Contents/Resources/AppIcon.icns"
            echo "Icon copied successfully."
        else
            echo "Warning: Icon file not found, using default icon."
        fi
    else
        echo "Warning: Application not found, using default icon."
    fi
fi

# 5. 生成 Info.plist
echo "Generating Info.plist..."
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
```

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| 应用名称无效 | 输出警告，创建无图标的默认 .app |
| 应用图标文件不存在 | 输出警告，跳过图标复制 |
| swift build 失败 | 脚本终止，输出错误信息 |

## 测试考虑

1. 测试无参数创建默认 .app
2. 测试指定有效应用名创建带图标的 .app
3. 测试指定无效应用名的错误处理
4. 测试不同应用（Zed、iTerm、Terminal、Ghostty）的图标提取
5. 测试创建的 .app 是否能正确发送通知并显示图标

## 文件变更清单

| 文件 | 操作 |
|------|------|
| `build.sh` | 修改 |

## 使用示例

```bash
# 创建默认版本
./build.sh

# 为 Zed 创建专用版本
./build.sh --app "Zed"

# 为 iTerm 创建专用版本
./build.sh --app "iTerm"

# 使用特定版本发送通知
apps/Zed/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --title "Test" --message "Hello"
```
