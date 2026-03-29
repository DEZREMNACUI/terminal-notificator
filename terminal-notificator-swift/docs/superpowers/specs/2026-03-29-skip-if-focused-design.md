# Skip If Focused Design

## 概述

本次设计旨在增加一个功能：当用户正在 focus 当前触发通知的窗口时，不发送通知并自动退出。默认开启此功能，除非用户显式关闭。

## 背景

有时候用户可能正在使用终端窗口，此时不需要收到通知会打断用户的工作流。通过检查当前最前端的窗口是否就是触发通知的窗口，可以避免在用户正在使用时发送不必要的通知。

## 功能设计

### 1. TerminalContext 扩展

在 `TerminalContext` 中新增 `isFrontmostAndActive()` 方法，用于检查当前 context 对应的窗口是否是当前最前端且活动的窗口。

#### 实现细节：

```swift
extension TerminalContext {
    @MainActor
    func isFrontmostAndActive() async -> Bool {
        // 1. 检查最前端应用是否匹配
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.bundleIdentifier == bundleId,
              frontmostApp.processIdentifier == appPid else {
            return false
        }
        
        // 2. 使用 AppleScript 检查最前端窗口是否匹配
        return await checkFrontmostWindowMatches(currentDirectory: currentDirectory)
    }
}

private func checkFrontmostWindowMatches(currentDirectory: String) async -> Bool {
    let dirName = (currentDirectory as NSString).lastPathComponent
    
    let script = """
    tell application "System Events"
        try
            set frontApp to first application process whose frontmost is true
            tell frontApp
            try
                set frontWin to first window
                set winName to name of frontWin
                if winName contains "\(currentDirectory)" then
                    return "true"
                else if winName contains "\(dirName)" then
                    return "true"
                else
                    return "false"
                end if
            on error
                return "false"
            end try
            end tell
        on error
            return "false"
        end try
    end tell
    """
    
    // 执行 AppleScript 并返回结果
    // ...
}
```

### 2. CLI 命令行选项

在 `TerminalNotificatorCommand` 中新增 `--always-show` / `-a` 标志：

```swift
@Flag(name: .shortAndLong, help: "Always show notification even if terminal is focused.")
var alwaysShow: Bool = false
```

### 3. 主流程检查

在 `TerminalNotificatorCommand.run()` 中，在检测到 context 后、发送通知前添加检查逻辑：

```swift
let context = try await TerminalContext.detect()

// 检查是否需要跳过
if !alwaysShow {
    let isFocused = await context.isFrontmostAndActive()
    if isFocused {
        if isVerbose {
            print("[INFO] Terminal window is currently focused, skipping notification.")
        }
        Darwin.exit(0)
    }
}

// 继续发送通知...
```

## 修改文件

- `Sources/TerminalNotificator/Context.swift` - 添加 `isFrontmostAndActive()` 方法和辅助函数
- `Sources/TerminalNotificator/TerminalNotificator.swift` - 添加 `--always-show` 选项和检查逻辑

## 数据流程

```
启动程序
  → 解析参数（包括 --always-show）
  → 检测 TerminalContext
  → 检查是否设置了 --always-show
    → 是 → 跳过检查，继续发送通知
    → 否 → 调用 context.isFrontmostAndActive()
      → 返回 true → 打印信息（verbose 模式）→ 退出（代码 0）
      → 返回 false → 继续发送通知 → 等待响应 → 退出
```

## 错误处理

- 如果检查最前端应用或窗口时出错，默认继续发送通知（不跳过）
- 保持向后兼容性，所有现有功能不受影响
- 如果 AppleScript 执行失败，继续发送通知

## 测试考虑

测试将通过手动方式进行：
1. 测试当窗口在 focus 时是否跳过通知
2. 测试当窗口不在 focus 时是否正常发送通知
3. 测试 `--always-show` 选项是否正常工作
4. 测试不同终端应用（Terminal、iTerm2、Zed、Ghostty）的兼容性
5. 测试错误情况下的回退行为
