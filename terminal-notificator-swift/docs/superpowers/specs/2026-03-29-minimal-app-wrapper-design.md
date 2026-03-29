# Minimal .app Wrapper Design

## 概述

将 terminal-notificator CLI 工具包装成最小化 .app 包，以解决 `UNErrorDomain error 1` (notificationNotAllowed) 问题。该错误发生在首次运行时，因为纯 CLI 工具无法触发 macOS 系统权限请求弹窗。

## 背景

当前 terminal-notificator 是一个纯 Swift CLI 工具，使用 `BundleIdSpoofer` 通过 method swizzling 来"欺骗"系统，让通知显示为来自终端应用（Terminal.app、iTerm2 等）。

**问题：** macOS 不允许 CLI 工具请求通知权限，导致首次运行时无法弹出权限请求对话框，直接返回 `UNErrorDomain error 1`。

## 设计目标

1. 解决通知权限请求问题
2. 保持命令行调用方式不变
3. 保持通知显示为终端应用图标
4. .app 包与 CLI 二进制同目录，方便管理

## 方案选择

选择 **LSUIElement 后台应用** 方案：

- .app 没有 Dock 图标，不显示在应用切换器
- CLI 二进制直接作为 .app 的主可执行文件
- 通过 .app 的 Info.plist 声明通知权限
- 保留 BundleIdSpoofer 逻辑，通知仍显示为终端应用

## 详细设计

### 1. .app 包结构

```
TerminalNotificator.app/
├── Contents/
│   ├── Info.plist              # 应用配置
│   ├── MacOS/
│   │   └── TerminalNotificator # CLI 可执行文件（直接复用）
│   └── Resources/
│       └── AppIcon.icns        # 可选图标
```

说明：
- `MacOS/TerminalNotificator` 就是当前的 CLI 二进制文件
- 不需要单独的 helper 或服务进程
- 整个 .app 只是一个"壳"，让 macOS 认为它是一个合法应用

### 2. Info.plist 配置

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

关键配置说明：
- `LSUIElement=true` — 后台应用，无 Dock 图标
- `NSUserNotificationAlertStyle=alert` — 请求完整通知权限
- `CFBundleIdentifier` — 用于系统识别和权限管理

### 3. 代码修改

**Notifier.swift：** 无需修改，保留 `BundleIdSpoofer` 类。

通知权限请求将自然通过 .app bundle 进行，BundleIdSpoofer 继续负责让通知显示为终端应用图标。

### 4. 构建流程

新增 `build.sh` 脚本：

```bash
#!/bin/bash
set -e

# 1. 构建 CLI 二进制
swift build -c release

# 2. 创建 .app 结构
APP_NAME="TerminalNotificator.app"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 3. 复制二进制
cp "$BUILD_DIR/TerminalNotificator" "$APP_DIR/Contents/MacOS/"

# 4. 生成 Info.plist
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

echo "Built: $APP_DIR"
```

### 5. 安装与使用

**安装位置：**
- 构建产物：`.build/release/TerminalNotificator.app/`
- 用户可将整个 .app 复制到任意位置

**使用方式：**
```bash
# 直接调用 .app 内的二进制
/path/to/TerminalNotificator.app/Contents/MacOS/TerminalNotificator --title "Test" --message "Hello"

# 或创建别名
alias terminal-notificator='/path/to/TerminalNotificator.app/Contents/MacOS/TerminalNotificator'
```

## 数据流程

```
用户调用 CLI
  → .app 内的二进制执行
    → UNUserNotificationCenter 请求权限
      → 系统识别 .app bundle，弹出权限请求对话框
        → 用户授权
          → BundleIdSpoofer 伪造终端应用身份
            → 发送通知（显示为终端应用图标）
```

## 权限管理

首次运行时，用户会看到标准的 macOS 通知权限请求对话框，显示 "Terminal Notificator" 请求发送通知。

用户可以在系统设置 → 通知中管理权限。

## 测试考虑

1. 首次运行时是否正确弹出权限请求
2. 授权后通知是否正常发送
3. 通知是否显示为终端应用图标
4. 点击通知后是否正确激活终端窗口
5. 不同终端应用（Terminal、iTerm2、Zed、Ghostty）的兼容性

## 文件变更清单

| 文件 | 操作 |
|------|------|
| `build.sh` | 新增 |
| `Sources/TerminalNotificator/Notifier.swift` | 无需修改 |

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| BundleIdSpoofer 在未来 macOS 版本失效 | 监控 macOS 更新，必要时调整方案 |
| 用户拒绝权限 | 提供清晰的错误提示，引导用户到系统设置 |
