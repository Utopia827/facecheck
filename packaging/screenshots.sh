#!/bin/bash
# Runs the simulator build and screenshots the intro, then the whole simulated flow, into shots/.
# Usage: packaging/screenshots.sh <path/to/FaceCheck.app>
set -euo pipefail

APP="$1"
ID="com.kobz.facecheck"
DEV=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
runtimes = sorted((k for k in d if "iOS" in k), key=lambda k: [int(x) for x in k.split("iOS-")[1].split("-")])
print(next(x["udid"] for x in d[runtimes[-1]] if x["name"].startswith("iPhone")))')

xcrun simctl boot "$DEV"
xcrun simctl bootstatus "$DEV" -b >/dev/null
xcrun simctl status_bar "$DEV" override --time 9:41 --batteryLevel 100 --cellularBars 4 || true
xcrun simctl install "$DEV" "$APP"
mkdir -p shots

xcrun simctl launch "$DEV" "$ID"
sleep 3
xcrun simctl io "$DEV" screenshot shots/00-intro.png
xcrun simctl terminate "$DEV" "$ID"

xcrun simctl launch "$DEV" "$ID" -autoplay
for i in $(seq -w 1 24); do
  sleep 0.5
  xcrun simctl io "$DEV" screenshot "shots/$i.png" >/dev/null 2>&1
done
ls shots
