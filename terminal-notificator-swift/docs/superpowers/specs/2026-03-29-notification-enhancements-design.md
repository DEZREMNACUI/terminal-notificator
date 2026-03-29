# Notification Enhancements Design

## 概述

本次设计旨在增强 terminal-notificator 的两个核心功能：
1. 用户点击通知后立即让通知消失
2. 点击通知后跳转到触发窗口，而不是最近使用的窗口

## 背景

目前，NSUserNotification 在点击后不会自动消失，需要点击"显示"按钮才会消失。同时，当一个应用有多个窗口时，点击通知后往往会跳转到最近使用的窗口，而不是触发通知的那个窗口。

## 功能 1：点击通知后让通知消失

### 设计方案

在 `NotificationManager` actor 中：
1. 保存对 `NSUserNotificationCenter` 的引用
2. 在 `didActivateNotification` 回调中，调用 `removeDeliveredNotification:` 方法移除被点击的通知

### 修改文件

- `Sources/TerminalNotificator/Notifier.swift`

### 实现细节

```swift
// 在 NotificationManager 中添加属性
private var notificationCenter: AnyObject?

// 在 send 方法中保存 notificationCenter 引用
self.notificationCenter = defaultCenter

// 在 didActivateNotification 中移除通知
@objc nonisolated func userNotificationCenter(_ center: Any, didActivateNotification notification: Any) {
    Task {
        if let notificationCenter = await self.notificationCenter {
            notificationCenter.perform(NSSelectorFromString("removeDeliveredNotification:"), with: notification)
        }
        await setIsClicked(true)
    }
}
```

## 功能 2：跳转到触发窗口而不是最近使用窗口

### 设计方案

1. 在发送通知时，收集并保存触发窗口的信息
2. 在激活窗口时，使用保存的窗口信息来精确匹配和激活触发窗口
3. 改进 AppleScript 脚本，使用更可靠的窗口匹配策略

### 修改文件

- `Sources/TerminalNotificator/Context.swift`
- `Sources/TerminalNotificator/NotificationService.swift`

### 实现细节

#### 新增 WindowInfo 结构体

```swift
struct WindowInfo {
    let windowName: String?
    let windowId: Int?
    let currentDirectory: String
}
```

#### 更新 TerminalContext 结构体

```swift
struct TerminalContext {
    let bundleId: String
    let appName: String
    let appPid: pid_t
    let windowInfo: WindowInfo?  // 新增
    
    // ... 其他代码保持不变
}
```

#### 改进 activateViaAppleScript 函数

增强 AppleScript 脚本来：
1. 优先使用保存的窗口信息
2. 回退到目录名匹配
3. 确保能正确找到并激活触发窗口

## 数据流程

### 通知发送流程

```
TerminalNotificatorCLI 
  → NotificationService.sendNotification()
    → NotificationManager.send()
      → 保存 notificationCenter 引用
      → 发送通知
      → 等待用户点击
```

### 通知点击流程

```
用户点击通知
  → didActivateNotification 回调
    → 从 notificationCenter 移除通知
    → 恢复 continuation 返回 true
    → NotificationService 调用 TerminalContext.activate()
      → 使用保存的窗口信息激活触发窗口
```

## 错误处理

- 如果无法移除通知，记录错误但不影响其他功能
- 如果无法找到精确的触发窗口，回退到当前的应用激活策略
- 保持向后兼容性，确保现有功能不受影响

## 测试考虑

测试将通过手动方式进行：
1. 测试点击通知后通知是否立即消失
2. 测试有多个窗口时是否激活正确的触发窗口
3. 测试不同终端应用（Terminal、iTerm2、Zed、Ghostty）的兼容性
4. 测试错误情况下的回退行为
