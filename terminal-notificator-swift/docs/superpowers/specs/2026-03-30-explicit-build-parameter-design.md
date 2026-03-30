# 入口脚本显式构建参数设计

## 背景

当前 `terminal-notificator` 入口脚本会自动检测终端应用类型，并在对应 .app 不存在时自动构建。用户希望改为显式控制：默认使用 default app，只有明确传入参数才构建特定终端的 app bundle。

## 目标

- 默认行为：使用 `apps/default/`，不存在则自动构建
- 显式构建：通过 `--build-app <AppName>` 参数指定要构建的 app
- 保留便利：通过 `--build-app auto` 支持自动检测终端类型

## 行为规范

### 参数格式

```
terminal-notificator [选项]
terminal-notificator --build-app <AppName> [选项]
terminal-notificator --build-app auto [选项]
```

### 行为矩阵

| 场景 | 目标 App | .app 不存在时 |
|------|----------|---------------|
| 无 `--build-app` | default | 自动构建 default |
| `--build-app <AppName>` | 指定的 AppName | 构建指定 app |
| `--build-app auto` | 自动检测的终端 | 构建检测到的 app |

### 参数处理

- `--build-app` 及其值由入口脚本消费，不传递给 Swift CLI
- 其他所有参数透传给 Swift CLI

## 技术设计

### 代码结构

```bash
#!/bin/bash
set -e

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ORIGINAL_PWD="$(pwd)"

# 终端检测函数（保留）
detect_terminal_app() {
    # ... 现有检测逻辑不变 ...
}

# 参数解析
BUILD_APP=""
REMAINING_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-app)
            BUILD_APP="$2"
            shift 2
            ;;
        *)
            REMAINING_ARGS+=("$1")
            shift
            ;;
    esac
done

# 确定目标 app
if [ -z "$BUILD_APP" ]; then
    APP_NAME="default"
elif [ "$BUILD_APP" = "auto" ]; then
    APP_NAME=$(detect_terminal_app)
else
    APP_NAME="$BUILD_APP"
fi

# 检查并构建
APP_PATH="$SCRIPT_DIR/apps/$APP_NAME/TerminalNotificator.app/Contents/MacOS/TerminalNotificator"

if [ ! -f "$APP_PATH" ]; then
    echo "Building .app bundle for $APP_NAME..."
    cd "$SCRIPT_DIR"
    if [ "$APP_NAME" = "default" ]; then
        ./build.sh
    else
        ./build.sh --app "$APP_NAME"
    fi
    cd "$ORIGINAL_PWD"
fi

# 执行
exec "$APP_PATH" "${REMAINING_ARGS[@]}"
```

### 修改文件

- `terminal-notificator`：入口脚本

### 不修改的文件

- `build.sh`：构建脚本逻辑不变
- Swift 源代码：不受影响

## 使用示例

```bash
# 首次使用，自动构建 default
terminal-notificator --title "Done" --message "Build complete"

# 为 Zed 构建 app bundle 并发送通知
terminal-notificator --build-app Zed --title "Done"

# 自动检测终端并构建
terminal-notificator --build-app auto --title "Done"

# 后续使用（已构建的 app）
terminal-notificator --title "Test"
```

## 测试要点

1. 无参数首次运行 → 自动构建 default
2. `--build-app Zed` → 构建 Zed app 并执行通知
3. `--build-app auto` → 检测终端类型并构建
4. 参数透传验证 → `--title`、`--message` 等正确传递给 Swift CLI
