import Foundation
import AppKit

struct ProcessContext {
    var bundleId: String?
    var appName: String?
    var appPid: pid_t?

    static func current() -> ProcessContext {
        var context = ProcessContext()
        
        // 1. 尝试从环境变量获取
        if let (appName, bundleId, pid) = getTerminalFromEnv() {
            context.appName = appName
            context.bundleId = bundleId
            context.appPid = pid
            return context
        }
        
        // 2. 如果环境变量没有，我们尝试通过进程树查找
        // 在纯 Swift CLI 中，获取父进程树比较麻烦，我们先尝试获取当前进程的父进程
        let ppid = getppid()
        if let (appName, bundleId, pid) = resolveAppInfo(startingPid: ppid) {
            context.appName = appName
            context.bundleId = bundleId
            context.appPid = pid
        }
        
        return context
    }
    
    func activate() -> Bool {
        guard let pid = appPid else { return false }
        
        // 先尝试用 AppleScript 激活特定窗口（参考你原有的 Rust 逻辑）
        if activateViaAppleScript(pid: pid) {
            return true
        }
        
        // 回退到用 NSWorkspace 激活整个应用
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.activate(options: .activateIgnoringOtherApps)
        }
        
        return false
    }
    
    private func activateViaAppleScript(pid: pid_t) -> Bool {
        let currentDir = FileManager.default.currentDirectoryPath
        let dirName = (currentDir as NSString).lastPathComponent
        
        let script = """
        tell application "System Events"
            try
                set targetProc to first process whose unix id is \(pid)
                tell targetProc
                    set targetWin to (first window whose name contains "\(dirName)")
                    perform action "AXRaise" of targetWin
                    set frontmost to true
                    return "true"
                end tell
            on error
                return "false"
            end try
        end tell
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output == "true"
            }
        } catch {
            print("Error running osascript: \(error)")
        }
        
        return false
    }
}

// MARK: - Helper Functions

private func getTerminalFromEnv() -> (String, String, pid_t)? {
    guard let termProgram = ProcessInfo.processInfo.environment["TERM_PROGRAM"] else {
        return nil
    }
    
    let mapping: [String: (String, String)] = [
        "zed": ("dev.zed.Zed", "Zed"),
        "ghostty": ("com.mitchellh.ghostty", "Ghostty"),
        "apple_terminal": ("com.apple.Terminal", "Terminal"),
        "iterm.app": ("com.googlecode.iterm2", "iTerm")
    ]
    
    guard let (bundleId, appName) = mapping[termProgram.lowercased()] else {
        return nil
    }
    
    if let pid = findTerminalPid(bundleId: bundleId) {
        return (appName, bundleId, pid)
    }
    
    return nil
}

private func findTerminalPid(bundleId: String) -> pid_t? {
    let workspace = NSWorkspace.shared
    let apps = workspace.runningApplications
    for app in apps {
        if app.bundleIdentifier == bundleId {
            return app.processIdentifier
        }
    }
    return nil
}

private func resolveAppInfo(startingPid: pid_t) -> (String, String, pid_t)? {
    // 简化版的进程树回溯（使用 sysctl 获取进程信息）
    var currentPid = startingPid
    
    while currentPid > 1 {
        if let app = NSRunningApplication(processIdentifier: currentPid) {
            let procName = app.localizedName ?? ""
            let lowerName = procName.lowercased()
            
            if let bundleId = app.bundleIdentifier {
                if !lowerName.contains("helper") &&
                   !lowerName.contains("zsh") &&
                   !lowerName.contains("bash") &&
                   !lowerName.contains("login") {
                    return (procName, bundleId, currentPid)
                }
            }
        }
        
        // 获取父进程 PID
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, currentPid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        if result == 0 {
            currentPid = info.kp_eproc.e_ppid
        } else {
            break
        }
    }
    
    return nil
}
