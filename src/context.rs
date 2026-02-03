use sysinfo::{System, Pid};
use std::process;
use std::env;
use objc2_app_kit::{NSRunningApplication, NSApplicationActivationOptions};
use objc2::rc::Retained;

pub struct ProcessContext {
    pub bundle_id: Option<String>,
    pub app_name: Option<String>,
    pub app_pid: Option<u32>,
}

impl ProcessContext {
    pub fn current() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();

        let current_pid = Pid::from_u32(process::id());
        
        let parent_pid = sys.process(current_pid)
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
        let mut current_pid = ppid;
        
        while let Some(proc) = sys.process(current_pid) {
            let pid_u32 = current_pid.as_u32();
            
            if let Some(bundle_id) = get_bundle_id(pid_u32) {
                self.bundle_id = Some(bundle_id);
                self.app_name = Some(proc.name().to_string());
                self.app_pid = Some(pid_u32);
                
                if !proc.name().to_lowercase().contains("helper") {
                    break;
                }
            }

            if let Some(next_ppid) = proc.parent() {
                current_pid = next_ppid;
            } else {
                break;
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
                    return app.activateWithOptions(NSApplicationActivationOptions::NSApplicationActivateIgnoringOtherApps);
                }
            }
        }
        false
    }

    fn activate_via_applescript(&self, pid: u32) -> bool {
        let current_dir = env::current_dir().ok();
        let dir_name = current_dir.and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()));

        if let Some(name) = dir_name {
            println!("Debug: Target project name: '{}'", name);
            
            // Improved AppleScript:
            // 1. Find the window matching the project name
            // 2. perform AXRaise on it (to make it the key window of the app)
            // 3. Activate the app (set frontmost)
            // This order prevents flickering (activating wrong window then switching)
            let script = format!(
                r#"
                tell application "System Events"
                    try
                        set targetProc to first process whose unix id is {}
                        
                        tell targetProc
                            set targetWin to (first window whose name contains "{}")
                            
                            -- Raise the specific window to be the top of the app's windows
                            perform action "AXRaise" of targetWin
                            
                            -- Then bring the app to the front
                            set frontmost to true
                            
                            return "true|match:" & (name of targetWin)
                        end tell
                    on error errMsg
                        return "error|" & errMsg
                    end try
                end tell
                "#,
                pid, name.replace("\"", "\\\"")
            );

            let output = process::Command::new("osascript")
                .arg("-e")
                .arg(script)
                .output();

            if let Ok(out) = output {
                let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
                let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();
                
                if stdout.starts_with("true") {
                    println!("Debug: AppleScript success: {}", stdout);
                    return true;
                } else {
                    println!("Debug: AppleScript did not find window. Result: '{}', Stderr: '{}'", stdout, stderr);
                }
            } else {
                println!("Debug: Failed to execute osascript");
            }
        } else {
            println!("Debug: Could not determine current directory name");
        }
        false
    }
}

fn get_bundle_id(pid: u32) -> Option<String> {
    unsafe {
        let app: Option<Retained<NSRunningApplication>> = NSRunningApplication::runningApplicationWithProcessIdentifier(pid as i32);
        app.and_then(|a| a.bundleIdentifier()).map(|s| s.to_string())
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
