mod cli;
mod context;
mod notifier;

use context::ProcessContext;
use std::{thread, time};

fn main() {
    println!("We will try to activate the parent application in 3 seconds...");
    println!("Please switch to another application (like a browser) NOW.");
    
    let ctx = ProcessContext::current();
    println!("Detected parent: {:?}", ctx.app_name);
    
    thread::sleep(time::Duration::from_secs(3));
    
    println!("Activating...");
    let success = ctx.activate();
    
    if success {
        println!("Successfully sent activation request.");
    } else {
        println!("Failed to send activation request.");
    }
}
