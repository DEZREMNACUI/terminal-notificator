#!/bin/bash

# terminal-notificator verification script

# Build the project
echo "Building terminal-notificator in release mode..."
cargo build --release

BIN="./target/release/terminal-notificator"

echo ""
echo "--- Verification Flow ---"
echo "1. We will sleep for 3 seconds."
echo "2. A notification will appear."
echo "3. PLEASE SWITCH TO ANOTHER APPLICATION (like a browser) during the sleep."
echo "4. When the notification appears, CLICK IT."
echo "5. Expectation: The focus should jump back to this terminal."
echo "--------------------------"
echo ""

sleep 3

echo "Sending notification..."
$BIN -t "Task Completed" -m "Click this notification to return to your terminal." -v

if [ $? -eq 0 ]; then
    echo "Verification script finished successfully."
else
    echo "Verification script failed."
fi
