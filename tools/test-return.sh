#!/bin/bash
set -euo pipefail
device=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; devices=json.load(sys.stdin)["devices"];print(next(d["udid"] for k in reversed(sorted(devices)) if "iOS" in k for d in devices[k] if d["name"].startswith("iPhone")))')
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
args=(-project QingJian.xcodeproj -scheme ReturnUI -destination "platform=iOS Simulator,id=$device" -derivedDataPath SimBuild)
xcodebuild "${args[@]}" build-for-testing > /tmp/qj-sim-build.log || { tail -100 /tmp/qj-sim-build.log; exit 1; }
xcrun simctl install "$device" SimBuild/Build/Products/Debug-iphonesimulator/QingJian.app
xcrun simctl spawn "$device" defaults write .GlobalPreferences AppleKeyboards -array "com.custom.ime.keyboard" "en_US@sw=QWERTY;hw=Automatic"
xcrun simctl spawn "$device" defaults write .GlobalPreferences AppleCurrentKeyboardLayoutInputSourceID -string "com.custom.ime.keyboard"
xcrun simctl shutdown "$device"
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
xcrun simctl ui "$device" appearance dark
xcodebuild "${args[@]}" -parallel-testing-enabled NO -resultBundlePath ReturnResult.xcresult test-without-building

