# 入口脚本显式构建参数实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修改 `terminal-notificator` 入口脚本，支持 `--build-app` 参数显式控制构建行为，默认使用 default app。

**Architecture:** 重构入口脚本的参数解析逻辑，提取 `--build-app` 参数，根据参数值决定目标 app，保留终端检测函数供 `--build-app auto` 使用。

**Tech Stack:** Bash shell script

---

## 文件结构

| 文件 | 操作 | 说明 |
|------|------|------|
| `terminal-notificator` | 修改 | 入口脚本，重构参数解析和 app 选择逻辑 |

---

### Task 1: 重构入口脚本

**Files:**
- Modify: `terminal-notificator`

- [ ] **Step 1: 重写入口脚本**

将整个 `terminal-notificator` 文件替换为以下内容：

```bash
#!/bin/bash
set -e

# 获取脚本所在目录（不改变当前工作目录）
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 保存原始工作目录
ORIGINAL_PWD="$(pwd)"

# 检测当前终端应用
detect_terminal_app() {
    local term_program="${TERM_PROGRAM:-}"

    case "$term_program" in
        "zed")
            echo "Zed"
            ;;
        "ghostty")
            echo "Ghostty"
            ;;
        "Apple_Terminal")
            echo "Terminal"
            ;;
        "iTerm.app")
            echo "iTerm"
            ;;
        *)
            # 尝试通过进程树检测
            local ppid=$(ps -p $$ -o ppid= | tr -d ' ')
            while [ "$ppid" -gt 1 ]; do
                local proc_name=$(ps -p "$ppid" -o comm= | tr -d ' ')
                case "$proc_name" in
                    *zed*|*Zed*)
                        echo "Zed"
                        return
                        ;;
                    *ghostty*|*Ghostty*)
                        echo "Ghostty"
                        return
                        ;;
                    *Terminal*)
                        echo "Terminal"
                        return
                        ;;
                    *iTerm*)
                        echo "iTerm"
                        return
                        ;;
                esac
                ppid=$(ps -p "$ppid" -o ppid= | tr -d ' ')
            done
            echo "default"
            ;;
    esac
}

# 参数解析：提取 --build-app 参数，其余参数透传
BUILD_APP=""
REMAINING_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-app)
            if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then
                BUILD_APP="$2"
                shift 2
            else
                echo "Error: --build-app requires an argument" >&2
                exit 1
            fi
            ;;
        *)
            REMAINING_ARGS+=("$1")
            shift
            ;;
    esac
done

# 确定目标 app
if [ -z "$BUILD_APP" ]; then
    # 无参数：默认使用 default
    APP_NAME="default"
elif [ "$BUILD_APP" = "auto" ]; then
    # auto：自动检测终端
    APP_NAME=$(detect_terminal_app)
else
    # 指定名称：使用指定值
    APP_NAME="$BUILD_APP"
fi

# 检查 .app 是否存在
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

# 调用对应的 .app 包，传递剩余参数
exec "$APP_PATH" "${REMAINING_ARGS[@]}"
```

- [ ] **Step 2: 验证脚本语法**

Run: `bash -n terminal-notificator`
Expected: 无输出（语法正确）

- [ ] **Step 3: 测试无参数默认行为**

Run: `./terminal-notificator --help`
Expected: 显示 Swift CLI 帮助信息（证明参数透传正常）

- [ ] **Step 4: 测试 --build-app 参数解析**

Run: `./terminal-notificator --build-app default --help`
Expected: 显示 Swift CLI 帮助信息（证明 --build-app 被消费，--help 被透传）

- [ ] **Step 5: 提交更改**

```bash
git add terminal-notificator
git commit -m "feat: 入口脚本支持 --build-app 参数显式控制构建"
```

---

### Task 2: 手动验证完整功能

- [ ] **Step 1: 验证默认构建 default**

Run: `rm -rf apps/default && ./terminal-notificator --title "Test" --message "Default build"`
Expected: 自动构建 default app 并发送通知

- [ ] **Step 2: 验证 --build-app 指定构建**

Run: `rm -rf apps/Zed && ./terminal-notificator --build-app Zed --title "Test" --message "Zed build"`
Expected: 构建 Zed app 并发送通知

- [ ] **Step 3: 验证 --build-app auto 检测构建**

Run: `rm -rf apps/Zed && ./terminal-notificator --build-app auto --title "Test" --message "Auto build"`
Expected: 检测当前终端类型，构建对应 app 并发送通知

- [ ] **Step 4: 验证参数缺失报错**

Run: `./terminal-notificator --build-app`
Expected: 输出错误信息 "Error: --build-app requires an argument" 并退出

- [ ] **Step 5: 最终提交**

```bash
git add -A
git commit -m "test: 验证 --build-app 参数功能"
```
