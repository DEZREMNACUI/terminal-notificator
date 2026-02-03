mod cli;
mod context;
mod notifier;

use clap::Parser;
use cli::Cli;
use context::ProcessContext;
use notifier::Notifier;

fn main() {
    let args = Cli::parse();
    
    if args.verbose {
        println!("Initializing context...");
    }

    let ctx = ProcessContext::current();

    if args.verbose {
        println!("Detected App: {:?}", ctx.app_name);
        println!("Bundle ID: {:?}", ctx.bundle_id);
    }

    // We default to Notifier::new() (sending as Terminal) to avoid the OS automatically 
    // activating the target app's main window when clicked. This allows our custom 
    // activation logic in ctx.activate() to handle the focus precisely without flickering.
    // 
    // If we used Notifier::with_bundle_id(bid), the notification would have the target app's icon,
    // but clicking it would force-activate the app via macOS default behavior before our code runs.
    let notifier = Notifier::new();
    /* 
    let notifier = if let Some(ref bid) = ctx.bundle_id {
        Notifier::with_bundle_id(bid)
    } else {
        Notifier::new()
    };
    */

    println!("Sending notification: {} - {}", args.title, args.message);
    println!("Waiting for click to activate parent application...");
    
    if notifier.send_and_wait(&args.title, &args.message) {
        println!("Notification clicked! Activating...");
        if ctx.activate() {
            println!("Successfully activated parent application.");
        } else {
            println!("Failed to activate parent application.");
        }
    } else {
        println!("Notification ignored or closed.");
    }
}
