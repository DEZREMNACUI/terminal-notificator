# Terminal Notificator 改进实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 通过环境变量识别终端 + 添加 10 秒超时功能

**Architecture:** 在 context.rs 中添加环境变量检测，优先级高于父进程链；在 main.rs 中添加超时线程

**Tech Stack:** Rust, objc2, sysinfo

---

## 修改文件

- `src/context.rs`：添加 `get_terminal_from_env` 函数并集成到 `resolve_app_info`
- `src/main.rs`：在发送通知后启动 10 秒超时线程

---

## Chunk 1: 添加终端环境变量检测

**Files:**
- Modify: `src/context.rs`

- [ ] **Step 1: 添加 get_terminal_from_env 函数**

在 `get_bundle_id` 函数之前添加：

```rust
fn get_terminal_from_env() -> Option<(String, String, u32)> {
    let term_program = std::env::var("TERM_PROGRAM").ok()?;

    let (bundle_id, app_name) = match term_program.to_lowercase().as_str() {
        "zed" => ("dev.zed.Zed", "Zed"),
        "ghostty" => ("com.mitchellh.ghostty", "Ghostty"),
        "Apple_Terminal" => ("com.apple.Terminal", "Terminal"),
        "iTerm.app" => ("com.googlecode.iterm2", "iTerm"),
        _ => return None,
    };

    // 获取终端进程的 PID
    if let Some(pid) = find_terminal_pid(bundle_id) {
        Some((app_name.to_string(), bundle_id.to_string(), pid))
    } else {
        None
    }
}

fn find_terminal_pid(bundle_id: &str) -> Option<u32> {
    unsafe {
        let workspace = NSWorkspace::sharedWorkspace();
        let apps = workspace.runningApplications();
        for app in apps {
            if let Some(bid) = app.bundleIdentifier() {
                if bid.to_string() == bundle_id {
                    return Some(app.processIdentifier() as u32);
                }
            }
        }
        None
    }
}
```

- [ ] **Step 2: 在 resolve_app_info 中添加环境变量检测优先逻辑**

在 `resolve_app_info` 函数开头添加：

```rust
fn resolve_app_info(&mut self, sys: &System, ppid: Pid) {
    // 首先尝试从环境变量获取终端信息
    if let Some((app_name, bundle_id, pid)) = get_terminal_from_env() {
        self.app_name = Some(app_name);
        self.bundle_id = Some(bundle_id);
        self.app_pid = Some(pid);
        return;
    }

    // 原有逻辑...
}
```

- [ ] **Step 3: 编译测试**

```bash
cargo build --release
```

预期：编译成功

- [ ] **Step 4: 提交**

```bash
git add src/context.rs
git commit -m "feat(context): 添加终端环境变量检测支持"
```

---

## Chunk 2: 添加超时功能

**Files:**
- Modify: `src/main.rs`

- [ ] **Step 1: 在发送通知后添加超时线程**

在 `src/main.rs` 的 `notifier.send_and_wait` 调用之后添加：

```rust
// 添加超时功能：10 秒后自动退出
let timeout_duration = std::time::Duration::from_secs(10);
std::thread::spawn(move || {
    std::thread::sleep(timeout_duration);
    println!("Timeout: exiting after 10 seconds");
    std::process::exit(0);
});
```

注意：这个超时应该在发送通知后立即启动，而不是等待用户交互后。

- [ ] **Step 2: 编译测试**

```bash
cargo build --release
```

预期：编译成功

- [ ] **Step 3: 手动测试**

```bash
# 运行程序，观察是否在 10 秒后自动退出
/Users/user/projects/terminal-notificator/target/release/terminal-notificator -t "测试" -m "10秒后将自动退出"
```

预期：10 秒后程序自动退出

- [ ] **Step 4: 提交**

```bash
git add src/main.rs
git commit -m "feat: 添加 10 秒超时自动退出功能"
```

---

## 验证清单

- [ ] 在 Zed 中运行，检测到 `TERM_PROGRAM=zed`
- [ ] 通知点击后正确激活 Zed
- [ ] 10 秒无操作自动退出
- [ ] 多个终端同时运行时也能正确识别

---

**Plan complete and saved to `docs/superpowers/plans/2026-03-16-terminal-notificator-improvement.md`. Ready to execute?**
