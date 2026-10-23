#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_TEST_ROOT=$(mktemp -d /tmp/xuanxuan-smoke.XXXXXX)
trap 'rm -rf "$TASK_TEST_ROOT"' EXIT
mkdir -p "$TASK_TEST_ROOT/MacSmoke.app/Contents/MacOS" "$TASK_TEST_ROOT/MacSmoke.app/Contents/Resources"
cp -R Examples/DemoWorkspace "$TASK_TEST_ROOT/MacSmoke.app/Contents/Resources/"
TASK_SWIFT_SOURCES=()
for TASK_SOURCE in native-writing-app/Sources/*.swift; do
  [[ "$TASK_SOURCE" == */main.swift ]] || TASK_SWIFT_SOURCES+=("$TASK_SOURCE")
done
xcrun swiftc -module-cache-path "$TASK_TEST_ROOT/cache" "${TASK_SWIFT_SOURCES[@]}" Tests/MacSmoke.swift -o "$TASK_TEST_ROOT/MacSmoke.app/Contents/MacOS/MacSmoke"
XUANXUAN_DEMO_ROOT="$TASK_TEST_ROOT/mac-data" "$TASK_TEST_ROOT/MacSmoke.app/Contents/MacOS/MacSmoke"
mkdir -p "$TASK_TEST_ROOT/CoreSmoke.app/Contents/MacOS" "$TASK_TEST_ROOT/CoreSmoke.app/Contents/Resources"
cp -R Examples/DemoWorkspace "$TASK_TEST_ROOT/CoreSmoke.app/Contents/Resources/"
xcrun swiftc -module-cache-path "$TASK_TEST_ROOT/cache" mobile-sync/Sources/XuanxuanCore/*.swift Tests/CoreSmoke.swift -o "$TASK_TEST_ROOT/CoreSmoke.app/Contents/MacOS/CoreSmoke"
XUANXUAN_DEMO_ROOT="$TASK_TEST_ROOT/core-data" "$TASK_TEST_ROOT/CoreSmoke.app/Contents/MacOS/CoreSmoke"
