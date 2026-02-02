use sysinfo::{System, Pid};
use std::process;
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
