# Dynamic App Bundle Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扩展 build.sh 脚本，支持根据应用名称动态创建带有对应应用图标的 .app 包。

**Architecture:** 修改现有 build.sh 脚本，添加参数解析、应用路径查找、图标提取逻辑，所有产物存放在 apps/ 目录下。

**Tech Stack:** Bash shell script, macOS 系统 tools (osascript, mdfind, defaults, codesign)

---

## File Structure

| 文件 | 职责 |
|------|------|
| `build.sh` | 构建脚本，支持 --app 参数动态创建 .app 包 |

---

### Task 1: 修改 build.sh 添加参数解析

**Files:**
- Modify: `build.sh`

- [ ] **Step 1: 读取现有 build.sh 内容**

Run: `cat build.sh`

- [ ] **Step 2: 添加参数解析逻辑**

在脚本开头添加参数解析：

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
```

- [ ] **Step 3: 验证脚本语法**

Run: `bash -n build.sh`
Expected: 无输出（语法正确）

---

### Task 2: 添加图标提取逻辑

**Files:**
- Modify: `build.sh`

- [ ] **Step 1: 在复制二进制后添加图标提取代码**

```bash
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
```

- [ ] **Step 2: 验证脚本语法**

Run: `bash -n build.sh`
Expected: 无输出（语法正确）

---

### Task 3: 更新 Info.plist 生成逻辑

**Files:**
- Modify: `build.sh`

- [ ] **Step 1: 更新 Info.plist 生成部分**

```bash
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
```

- [ ] **Step 2: 更新注册和签名部分**

```bash
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
```

- [ ] **Step 3: 验证完整脚本语法**

Run: `bash -n build.sh`
Expected: 无输出（语法正确）

---

### Task 4: 测试默认构建

**Files:**
- 无新增文件

- [ ] **Step 1: 测试无参数构建**

Run: `./build.sh`
Expected:
```
Building CLI binary...
Creating .app bundle structure at apps/default...
Copying binary...
Generating Info.plist...
Registering and signing app bundle...

Build complete!
App bundle: apps/default/TerminalNotificator.app

Usage:
  apps/default/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --title "Test" --message "Hello"
```

- [ ] **Step 2: 验证默认 .app 结构**

Run: `ls -la apps/default/TerminalNotificator.app/Contents/`
Expected: 显示 MacOS, Resources, Info.plist

- [ ] **Step 3: 测试默认 .app 功能**

Run: `apps/default/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --version`
Expected: `2.0.0`

---

### Task 5: 测试带图标构建

**Files:**
- 无新增文件

- [ ] **Step 1: 测试 Zed 图标构建**

Run: `./build.sh --app "Zed"`
Expected: 输出包含 "Extracting icon from Zed..." 和 "Icon copied successfully"

- [ ] **Step 2: 验证 Zed .app 结构**

Run: `ls -la apps/Zed/TerminalNotificator.app/Contents/Resources/`
Expected: 显示 AppIcon.icns

- [ ] **Step 3: 验证 Info.plist 包含图标配置**

Run: `cat apps/Zed/TerminalNotificator.app/Contents/Info.plist`
Expected: 包含 `<key>CFBundleIconFile</key>` 和 `<string>AppIcon</string>`

- [ ] **Step 4: 测试 Zed .app 功能**

Run: `apps/Zed/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --title "Test" --message "Hello from Zed" --verbose --always-show`
Expected: 通知发送成功，显示 Zed 图标

---

### Task 6: 测试无效应用名处理

**Files:**
- 无新增文件

- [ ] **Step 1: 测试无效应用名**

Run: `./build.sh --app "NonExistentApp12345"`
Expected: 输出包含 "Warning: Application 'NonExistentApp12345' not found"，但 .app 仍然创建成功

- [ ] **Step 2: 验证无效应用名的 .app 结构**

Run: `ls -la apps/NonExistentApp12345/TerminalNotificator.app/Contents/`
Expected: 显示 MacOS, Resources, Info.plist（Resources 可能为空或无 AppIcon.icns）

---

### Task 7: 更新 test.sh

**Files:**
- Modify: `test.sh`

- [ ] **Step 1: 更新 test.sh 使用新的 apps 目录**

```bash
#!/bin/bash

# 获取脚本所在的目录
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# 构建 .app 包（默认版本）
echo "📦 正在构建 .app 包..."
./build.sh

# 获取 .app 内的二进制文件路径
APP_PATH="./apps/default/TerminalNotificator.app/Contents/MacOS/TerminalNotificator"

if [ ! -f "$APP_PATH" ]; then
    echo "❌ 构建失败，找不到可执行文件: $APP_PATH"
    exit 1
fi

echo "✅ 构建成功！"
echo "⏳ 等待 2 秒钟... (请在此期间切换到其他窗口，比如浏览器或桌面)"

# 等待 2 秒
sleep 2

echo "🚀 发送通知！"
# 执行通知程序，并开启 verbose 模式以便查看详细日志
"$APP_PATH" -t "任务完成" -m "你的长耗时脚本已经运行完毕，点击返回终端。" -v

echo "✨ 脚本结束。"
```

- [ ] **Step 2: 运行更新后的测试脚本**

Run: `./test.sh`
Expected: 所有步骤正常执行

- [ ] **Step 3: 提交代码**

```bash
git add build.sh test.sh
git commit -m "feat: 支持动态创建带图标的 .app 包

- 添加 --app 参数支持指定应用名称
- 自动提取目标应用的图标
- 所有产物存放在 apps/ 目录下
- 支持无参数创建默认版本"
```

---

## Self-Review Checklist

**1. Spec coverage:**
- [x] 命令行接口 — Task 1, 4, 5
- [x] 目录结构 — Task 1
- [x] 图标获取逻辑 — Task 2
- [x] Info.plist 配置 — Task 3
- [x] 错误处理 — Task 6
- [x] 测试 — Task 4, 5, 6

**2. Placeholder scan:** 无 TBD/TODO 占位符

**3. Type consistency:** 不涉及类型定义，无需检查
