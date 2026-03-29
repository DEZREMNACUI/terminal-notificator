# Auto-Routing Entry Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建一个入口脚本，自动检测终端应用并调用对应的 .app 包，如不存在则自动构建。

**Architecture:** 创建 `terminal-notificator` shell 入口脚本，检测终端应用 → 检查 .app 包 → 自动构建（如需）→ 调用对应 .app。

**Tech Stack:** Bash shell script

---

## File Structure

| 文件 | 职责 |
|------|------|
| `terminal-notificator` | 入口脚本，自动路由到对应的 .app 包 |

---

### Task 1: 创建入口脚本

**Files:**
- Create: `terminal-notificator`

- [ ] **Step 1: 创建 terminal-notificator 入口脚本**

```bash
#!/bin/bash
set -e

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

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

# 检测终端应用
APP_NAME=$(detect_terminal_app)
APP_PATH="apps/$APP_NAME/TerminalNotificator.app/Contents/MacOS/TerminalNotificator"

# 检查 .app 是否存在，不存在则构建
if [ ! -f "$APP_PATH" ]; then
    echo "Building .app bundle for $APP_NAME..."
    if [ "$APP_NAME" = "default" ]; then
        ./build.sh
    else
        ./build.sh --app "$APP_NAME"
    fi
fi

# 调用对应的 .app 包，传递所有参数
exec "$APP_PATH" "$@"
```

- [ ] **Step 2: 设置执行权限**

Run: `chmod +x terminal-notificator`
Expected: 无输出

- [ ] **Step 3: 验证脚本语法**

Run: `bash -n terminal-notificator`
Expected: 无输出（语法正确）

---

### Task 2: 测试入口脚本

**Files:**
- 无新增文件

- [ ] **Step 1: 测试帮助信息**

Run: `./terminal-notificator --help`
Expected: 显示帮助信息

- [ ] **Step 2: 测试版本信息**

Run: `./terminal-notificator --version`
Expected: `2.0.0`

- [ ] **Step 3: 测试通知发送**

Run: `./terminal-notificator --title "Auto Test" --message "Testing auto-routing" --verbose --always-show`
Expected: 通知发送成功，显示对应终端应用图标

---

### Task 3: 更新 test.sh 使用入口脚本

**Files:**
- Modify: `test.sh`

- [ ] **Step 1: 更新 test.sh**

```bash
#!/bin/bash

# 获取脚本所在的目录
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🚀 发送通知！"
# 执行通知程序，自动检测终端应用
./terminal-notificator -t "任务完成" -m "你的长耗时脚本已经运行完毕，点击返回终端。" -v

echo "✨ 脚本结束。"
```

- [ ] **Step 2: 运行测试脚本**

Run: `./test.sh`
Expected: 通知发送成功

- [ ] **Step 3: 提交代码**

```bash
git add terminal-notificator test.sh
git commit -m "feat: 添加自动路由入口脚本

- 自动检测当前终端应用
- 自动构建缺失的 .app 包
- 透明转发所有参数"
```

---

## Self-Review Checklist

**1. Spec coverage:**
- [x] 自动检测终端应用 — Task 1
- [x] 检查 .app 包存在 — Task 1
- [x] 自动构建缺失的 .app — Task 1
- [x] 调用对应 .app 包 — Task 1

**2. Placeholder scan:** 无 TBD/TODO 占位符

**3. Type consistency:** 不涉及类型定义，无需检查
