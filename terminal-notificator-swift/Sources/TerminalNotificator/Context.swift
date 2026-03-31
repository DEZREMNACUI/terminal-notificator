import Foundation
import AppKit

struct TerminalContext {
    let bundleId: String
    let appName: String
    let appPid: pid_t
    let currentDirectory: String

    /// 是否支持 OSC 9 通知（如 Ghostty）
    var supportsOSC9: Bool {
        return bundleId == "com.mitchellh.ghostty"
    }

    @MainActor
    static func detect() async throws -> TerminalContext {
        // 1. 尝试从环境变量获取
        if let context = await getTerminalFromEnv() {
            return context
        }

        // 2. 如果环境变量没有，通过进程树查找
        let ppid = getppid()
        if let context = try await resolveAppInfo(startingPid: ppid) {
            return context
        }

        throw NotificationError.terminalContextNotFound
    }

    @MainActor
    func activate() async -> Bool {
        // 先尝试用 AppleScript 激活特定窗口
        if await activateViaAppleScript(pid: appPid, currentDirectory: currentDirectory) {
            return true
        }

        // 回退到用 NSWorkspace 激活整个应用
        if let app = NSRunningApplication(processIdentifier: appPid) {
            return app.activate(options: [])
        }

        return false
    }
}

// MARK: - Focus Check

extension TerminalContext {
    @MainActor
    func isFrontmostAndActive() async -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        guard frontmostApp.bundleIdentifier == bundleId,
              frontmostApp.processIdentifier == appPid else {
            return false
        }

        // 对于某些终端（如 Ghostty），窗口标题是命令而非目录
        // 如果应用本身在焦点，就认为终端在焦点
        let terminalsToSkipWindowCheck = ["com.mitchellh.ghostty"]
        if terminalsToSkipWindowCheck.contains(bundleId) {
            return true
        }

        // 对于其他终端，检查窗口是否匹配目录
        return await checkFrontmostWindowMatches(currentDirectory: currentDirectory)
    }
}

// MARK: - Helper Functions

@MainActor
private func getTerminalFromEnv() async -> TerminalContext? {
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

    if let pid = await findTerminalPid(bundleId: bundleId) {
        let currentDir = FileManager.default.currentDirectoryPath
        return TerminalContext(bundleId: bundleId, appName: appName, appPid: pid, currentDirectory: currentDir)
    }

    return nil
}

@MainActor
private func findTerminalPid(bundleId: String) async -> pid_t? {
    let workspace = NSWorkspace.shared
    let apps = workspace.runningApplications
    for app in apps {
        if app.bundleIdentifier == bundleId {
            return app.processIdentifier
        }
    }
    return nil
}

@MainActor
private func resolveAppInfo(startingPid: pid_t) async throws -> TerminalContext? {
    var currentPid = startingPid
    let currentDir = FileManager.default.currentDirectoryPath

    while currentPid > 1 {
        if let app = NSRunningApplication(processIdentifier: currentPid) {
            let procName = app.localizedName ?? ""
            let lowerName = procName.lowercased()

            if let bundleId = app.bundleIdentifier {
                if !lowerName.contains("helper") &&
                   !lowerName.contains("zsh") &&
                   !lowerName.contains("bash") &&
                   !lowerName.contains("login") {
                    return TerminalContext(bundleId: bundleId, appName: procName, appPid: currentPid, currentDirectory: currentDir)
                }
            }
        }

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

// MARK: - AppleScript Helper

/// 执行 AppleScript 并返回输出结果
private func runAppleScript(_ script: String) -> String? {
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]

    let pipe = Pipe()
    task.standardOutput = pipe

    do {
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return nil
    }
}

private func activateViaAppleScript(pid: pid_t, currentDirectory: String) async -> Bool {
    let dirName = (currentDirectory as NSString).lastPathComponent

    let script = """
    tell application "System Events"
        try
            set targetProc to first process whose unix id is \(pid)
            tell targetProc
                -- 首先尝试匹配完整目录路径
                set targetWin to missing value
                try
                    set targetWin to (first window whose name contains "\(currentDirectory)")
                on error
                    try
                        -- 回退到只匹配目录名
                        set targetWin to (first window whose name contains "\(dirName)")
                    on error
                        -- 如果都找不到，使用第一个窗口
                        set targetWin to first window
                    end try
                end try

                if targetWin is not missing value then
                    perform action "AXRaise" of targetWin
                    set frontmost to true
                    return "true"
                end if
                return "false"
            end tell
        on error
            return "false"
        end try
    end tell
    """

    return runAppleScript(script) == "true"
}

@MainActor
private func checkFrontmostWindowMatches(currentDirectory: String) async -> Bool {
    let dirName = (currentDirectory as NSString).lastPathComponent

    let script = """
    tell application "System Events"
        try
            set frontApp to first application process whose frontmost is true
            tell frontApp
                try
                    set frontWin to first window
                    return name of frontWin
                on error
                    return ""
                end try
            end tell
        on error
            return ""
        end try
    end tell
    """

    guard let winName = runAppleScript(script), !winName.isEmpty else {
        return false
    }

    return winName.contains(currentDirectory) || winName.contains(dirName)
}
