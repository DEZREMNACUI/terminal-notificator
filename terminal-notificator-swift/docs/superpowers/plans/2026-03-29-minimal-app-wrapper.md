# Minimal .app Wrapper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 CLI 工具包装成最小化 .app 包，解决通知权限请求问题。

**Architecture:** 创建 LSUIElement 后台应用包装，CLI 二进制直接作为 .app 主可执行文件，通过 Info.plist 声明通知权限。

**Tech Stack:** Swift 5.9, macOS 15.0+, Bash shell script

---

## File Structure

| 文件 | 职责 |
|------|------|
| `build.sh` | 构建脚本，生成 .app 包结构 |
| `Info.plist` | .app 配置文件（由 build.sh 生成） |

---

### Task 1: 创建构建脚本

**Files:**
- Create: `build.sh`

- [ ] **Step 1: 创建 build.sh 脚本**

```bash
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
```

- [ ] **Step 2: 设置脚本执行权限**

Run: `chmod +x build.sh`
Expected: 无输出，脚本变为可执行

- [ ] **Step 3: 运行构建脚本测试**

Run: `./build.sh`
Expected:
```
Building CLI binary...
Creating .app bundle structure...
Copying binary...
Generating Info.plist...

Build complete!
App bundle: .build/release/TerminalNotificator.app

Usage:
  .build/release/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --title "Test" --message "Hello"
```

- [ ] **Step 4: 验证 .app 结构**

Run: `ls -la .build/release/TerminalNotificator.app/Contents/`
Expected:
```
drwxr-xr-x  MacOS
drwxr-xr-x  Resources
-rw-r--r--   Info.plist
```

- [ ] **Step 5: 验证 Info.plist 内容**

Run: `cat .build/release/TerminalNotificator.app/Contents/Info.plist`
Expected:
```xml
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
```

- [ ] **Step 6: 验证二进制文件存在**

Run: `ls -la .build/release/TerminalNotificator.app/Contents/MacOS/TerminalNotificator`
Expected: 显示可执行文件信息

- [ ] **Step 7: 提交代码**

```bash
git add build.sh
git commit -m "feat: 添加 .app 包装构建脚本"
```

---

### Task 2: 功能测试

**Files:**
- 无新增文件

- [ ] **Step 1: 测试 .app 内的 CLI 基本功能**

Run: `.build/release/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --help`
Expected: 显示帮助信息

- [ ] **Step 2: 测试 .app 内的 CLI 版本信息**

Run: `.build/release/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --version`
Expected: `2.0.0`

- [ ] **Step 3: 测试通知发送（首次运行应弹出权限请求）**

Run: `.build/release/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --title "Test" --message "Hello from .app" --verbose`
Expected:
- 首次运行：系统弹出通知权限请求对话框
- 授权后：通知正常发送，显示为终端应用图标
- 输出包含 `[INFO]` 日志

- [ ] **Step 4: 测试通知点击激活终端**

Run: `.build/release/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --title "Click Test" --message "Click me" --verbose`
Expected:
- 点击通知后，终端窗口被激活
- 输出包含 `[INFO] Notification clicked!`

---

### Task 3: 更新现有 test.sh

**Files:**
- Modify: `test.sh`

- [ ] **Step 1: 读取现有 test.sh 内容**

Run: `cat test.sh`

- [ ] **Step 2: 更新 test.sh 使用 .app 内的二进制**

将测试脚本修改为使用 .app 包装后的二进制：

```bash
#!/bin/bash
set -e

# 构建测试
swift build

# 运行单元测试
swift test

# 构建 .app 包
./build.sh

# 功能测试
echo "Testing .app bundle..."
APP_PATH=".build/release/TerminalNotificator.app/Contents/MacOS/TerminalNotificator"

# 测试帮助
$APP_PATH --help

# 测试版本
$APP_PATH --version

echo "All tests passed!"
```

- [ ] **Step 3: 运行更新后的测试脚本**

Run: `./test.sh`
Expected: 所有测试通过

- [ ] **Step 4: 提交代码**

```bash
git add test.sh
git commit -m "test: 更新测试脚本使用 .app 包装"
```

---

## Self-Review Checklist

**1. Spec coverage:**
- [x] .app 包结构 — Task 1
- [x] Info.plist 配置 — Task 1
- [x] 构建流程 — Task 1
- [x] 功能测试 — Task 2
- [x] 无需修改 Notifier.swift — 确认

**2. Placeholder scan:** 无 TBD/TODO 占位符

**3. Type consistency:** 不涉及类型定义，无需检查
