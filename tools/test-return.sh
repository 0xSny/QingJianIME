#!/bin/bash
set -euo pipefail
device=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; devices=json.load(sys.stdin)["devices"];print(next(d["udid"] for k in sorted(devices,key=lambda x:("iOS-18-5" not in x,x)) if "iOS" in k for d in devices[k] if d["name"].startswith("iPhone")))')
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
xcrun simctl boot "$device"
args=(-project QingJian.xcodeproj -scheme ReturnUI -destination "platform=iOS Simulator,id=$device" -derivedDataPath SimBuild)
xcodebuild "${args[@]}" build-for-testing > /tmp/qj-sim-build.log || { tail -100 /tmp/qj-sim-build.log; exit 1; }
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" SimBuild/Build/Products/Debug-iphonesimulator/QingJian.app
xcrun simctl ui "$device" appearance dark
trap 'mkdir -p ReturnDiagnostics; xcrun simctl io "$device" screenshot ReturnDiagnostics/final.png || true; find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -name "Keyboard*.ips" -exec cp {} ReturnDiagnostics/ \; 2>/dev/null || true; if [ -d ReturnResult.xcresult ]; then xcrun xcresulttool export attachments --path ReturnResult.xcresult --output-path ReturnDiagnostics/attachments || true; fi' EXIT
xcodebuild "${args[@]}" -parallel-testing-enabled NO -resultBundlePath ReturnResult.xcresult test-without-building

