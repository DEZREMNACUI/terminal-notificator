use sysinfo::{System, Pid};
use std::process;
use objc2_app_kit::NSRunningApplication;
use objc2::rc::Retained;

pub struct ProcessContext {
    pub pid: u32,
    pub parent_pid: Option<u32>,
    pub bundle_id: Option<String>,
    pub app_name: Option<String>,
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
            pid: current_pid.as_u32(),
            parent_pid,
            bundle_id: None,
            app_name: None,
        };

        if let Some(ppid) = parent_pid {
            context.resolve_app_info(&sys, Pid::from_u32(ppid));
        }

        context
    }

    fn resolve_app_info(&mut self, sys: &System, ppid: Pid) {
        let mut current_ppid = ppid;
        
        while let Some(proc) = sys.process(current_ppid) {
            let name = proc.name().to_lowercase();
            
            // Try to get Bundle ID using AppKit
            if let Some(bundle_id) = get_bundle_id(current_ppid.as_u32()) {
                self.bundle_id = Some(bundle_id);
                self.app_name = Some(proc.name().to_string());
                break;
            }

            // Fallback for some common apps if bundle ID fails
            if name.contains("cursor") || 
               name.contains("warp") || 
               name.contains("iterm") || 
               name.contains("terminal") ||
               name.contains("vscode") ||
               name.contains("code") {
                
                self.app_name = Some(proc.name().to_string());
                break;
            }

            if let Some(next_ppid) = proc.parent() {
                current_ppid = next_ppid;
            } else {
                break;
            }
        }
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
        assert!(context.pid > 0);
        assert!(context.parent_pid.is_some());
    }
}