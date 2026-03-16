use block2::RcBlock;
use objc2::rc::Retained;
use objc2_app_kit::{
    NSApplicationActivationOptions, NSRunningApplication, NSWorkspace,
    NSWorkspaceDidActivateApplicationNotification,
};
use objc2_foundation::{NSNotification, NSOperationQueue};
use std::env;
use std::process;
use std::ptr::NonNull;
use std::rc::Rc;
use sysinfo::{Pid, System};

#[derive(Clone)]
pub struct ProcessContext {
    pub bundle_id: Option<String>,
    pub app_name: Option<String>,
    pub app_pid: Option<u32>,
}

impl ProcessContext {
    pub fn start_focus_monitoring(&self) {
        if let Some(target_pid) = self.app_pid {
            unsafe {
                let workspace = Rc::new(NSWorkspace::sharedWorkspace());
                let workspace_ref = workspace.clone();
                let check_and_exit_if_focused = move || {
                    // When notified, check if the frontmost app is our target
                    if let Some(front) = workspace_ref.frontmostApplication() {
                        if front.processIdentifier() as u32 == target_pid {
                            std::process::exit(0);
                        }
                    }
                };

                check_and_exit_if_focused();

                let notification_center = workspace.notificationCenter();
                let queue = NSOperationQueue::mainQueue();

                // Monitor application activation events
                let block = RcBlock::new(move |_: NonNull<NSNotification>| {
                    check_and_exit_if_focused();
                });

                let block_ptr: &block2::Block<dyn Fn(NonNull<NSNotification>)> = &block;

                notification_center.addObserverForName_object_queue_usingBlock(
                    Some(NSWorkspaceDidActivateApplicationNotification),
                    None,
                    Some(&queue),
                    block_ptr,
                );

                // Leak the block to keep it alive for the duration of the program
                Box::leak(Box::new(block));
            }
        }
    }

    pub fn current() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();

        let current_pid = Pid::from_u32(process::id());

        let parent_pid = sys
            .process(current_pid)
            .and_then(|p| p.parent())
            .map(|p| p.as_u32());

        let mut context = ProcessContext {
            bundle_id: None,
            app_name: None,
            app_pid: None,
        };

        if let Some(ppid) = parent_pid {
            context.resolve_app_info(&sys, Pid::from_u32(ppid));
        }

        context
    }

    fn resolve_app_info(&mut self, sys: &System, ppid: Pid) {
        // 首先尝试从环境变量获取终端信息
        if let Some((app_name, bundle_id, pid)) = get_terminal_from_env() {
            self.app_name = Some(app_name);
            self.bundle_id = Some(bundle_id);
            self.app_pid = Some(pid);
            return;
        }

        let mut current_pid = ppid;

        while let Some(proc) = sys.process(current_pid) {
            let pid_u32 = current_pid.as_u32();
            let proc_name = proc.name();

            if let Some(bundle_id) = get_bundle_id(pid_u32) {
                self.bundle_id = Some(bundle_id);
                self.app_name = Some(proc_name.to_string());
                self.app_pid = Some(pid_u32);

                if !proc_name.to_lowercase().contains("helper")
                    && !proc_name.to_lowercase().contains("zsh")
                    && !proc_name.to_lowercase().contains("bash")
                    && !proc_name.to_lowercase().contains("login")
                {
                    break;
                }
            }

            if let Some(next_ppid) = proc.parent() {
                current_pid = next_ppid;
            } else {
                break;
            }
        }

        // Fallback for Ghostty or other terminals that break the process tree
        if self.app_pid.is_none() {
            for proc in sys.processes().values() {
                let name = proc.name().to_lowercase();
                if name.contains("ghostty") || name.contains("zed") {
                    let pid = proc.pid().as_u32();
                    if let Some(bid) = get_bundle_id(pid) {
                        self.bundle_id = Some(bid);
                        self.app_name = Some(proc.name().to_string());
                        self.app_pid = Some(pid);
                        break;
                    }
                }
            }
        }
    }

    pub fn activate(&self) -> bool {
        if let Some(pid) = self.app_pid {
            // Try AppleScript first for specific window activation
            if self.activate_via_applescript(pid) {
                return true;
            }

            unsafe {
                let app = NSRunningApplication::runningApplicationWithProcessIdentifier(pid as i32);
                if let Some(app) = app {
                    #[allow(deprecated)]
                    return app.activateWithOptions(
                        NSApplicationActivationOptions::NSApplicationActivateIgnoringOtherApps,
                    );
                }
            }
        }
        false
    }

    fn activate_via_applescript(&self, pid: u32) -> bool {
        let current_dir = env::current_dir().ok();
        let dir_name =
            current_dir.and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()));

        if let Some(name) = dir_name {
            let script = format!(
                r#"
                tell application "System Events"
                    try
                        set targetProc to first process whose unix id is {}
                        tell targetProc
                            set targetWin to (first window whose name contains "{}")
                            perform action "AXRaise" of targetWin
                            set frontmost to true
                            return "true"
                        end tell
                    on error
                        return "false"
                    end try
                end tell
                "#,
                pid,
                name.replace("\"", "\\\"")
            );

            let output = process::Command::new("osascript")
                .arg("-e")
                .arg(script)
                .output();

            if let Ok(out) = output {
                let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
                return stdout == "true";
            }
        }
        false
    }
}

fn get_bundle_id(pid: u32) -> Option<String> {
    unsafe {
        let app: Option<Retained<NSRunningApplication>> =
            NSRunningApplication::runningApplicationWithProcessIdentifier(pid as i32);
        app.and_then(|a| a.bundleIdentifier())
            .map(|s| s.to_string())
    }
}

/// 从环境变量获取终端信息
/// 读取 TERM_PROGRAM 环境变量来识别终端类型
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

/// 通过 bundle ID 查找终端进程的 PID
fn find_terminal_pid(bundle_id: &str) -> Option<u32> {
    unsafe {
        let workspace = NSWorkspace::sharedWorkspace();
        let apps = workspace.runningApplications();
        // 使用索引遍历 NSArray
        let count = apps.count();
        for i in 0..count {
            let app = apps.objectAtIndex(i);
            if let Some(bid) = app.bundleIdentifier() {
                if bid.to_string() == bundle_id {
                    return Some(app.processIdentifier() as u32);
                }
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_current_context() {
        let context = ProcessContext::current();
        // Just verify it doesn't crash and we get some info
        assert!(context.app_name.is_some() || context.bundle_id.is_some());
    }
}
