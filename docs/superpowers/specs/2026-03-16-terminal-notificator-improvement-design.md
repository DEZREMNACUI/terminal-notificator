# Terminal Notificator 改进设计

## 背景

当前 terminal-notificator 在检测终端时存在问题：
- 当父进程链断裂时（如 Zed、Ghostty 等现代终端），fallback 逻辑会遍历所有终端进程并随机选择一个
- 如果同时运行多个终端（如 Zed 和 Ghostty），可能导致激活错误的终端

## 目标

1. **提高终端识别准确性**：通过环境变量 `TERM_PROGRAM` 准确识别启动命令的终端
2. **添加超时功能**：发送通知后 10 秒无响应则自动退出

## 方案

### 1. 终端识别优化

通过读取 `TERM_PROGRAM` 环境变量来识别终端：

```rust
fn get_terminal_from_env() -> Option<(String, String)> {
    let term_program = std::env::var("TERM_PROGRAM").ok()?;

    let bundle_id = match term_program.to_lowercase().as_str() {
        "zed" => Some("dev.zed.Zed"),
        "ghostty" => Some("com.mitchellh.ghostty"),
        "Apple_Terminal" => Some("com.apple.Terminal"),
        "iTerm.app" => Some("com.googlecode.iterm2"),
        _ => None,
    }?;

    Some((term_program, bundle_id.to_string()))
}
```

识别优先级：
1. 首先尝试 `TERM_PROGRAM` 环境变量
2. 然后尝试父进程链
3. 最后 fallback 到遍历终端进程

### 2. 超时功能

发送通知后启动 10 秒定时器，超时后自动退出：

```rust
// 在发送通知后
std::thread::spawn(move || {
    std::thread::sleep(std::time::Duration::from_secs(10));
    std::process::exit(0);
});
```

## 修改文件

- `src/context.rs`：添加环境变量检测逻辑
- `src/main.rs`：添加超时功能

## 测试场景

1. 只运行 Zed 时，检测到 `TERM_PROGRAM=zed` ✅
2. 只运行 Ghostty 时，检测到 `TERM_PROGRAM=ghostty` ✅
3. 同时运行 Zed 和 Ghostty 时，准确识别当前终端 ✅
4. 发送通知后 10 秒无操作，程序自动退出 ✅

## 实现状态

| 功能 | 状态 | 提交 |
|------|------|------|
| 终端环境变量检测 | ✅ 已完成 | `aca7b01` |
| 10 秒超时退出 | ✅ 已完成 | `e24d8d4` |
