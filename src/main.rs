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

    let notifier = if let Some(ref bid) = ctx.bundle_id {
        Notifier::with_bundle_id(bid)
    } else {
        Notifier::new()
    };

    println!("Sending notification: {} - {}", args.title, args.message);
    
    if notifier.send(&args.title, &args.message) {
        println!("Notification sent successfully.");
    } else {
        println!("Failed to send notification.");
    }
}