#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SimGate test runner.
#
# Usage:
#   scripts/test.sh            # run everything (unit + widget + e2e)
#   scripts/test.sh -u         # unit + widget only (fast, no HTTP server)
#   scripts/test.sh -e         # e2e HTTP server tests only
#   scripts/test.sh -i         # integration tests (requires a device)
#
# All host-runnable tests exit non-zero on failure so CI can rely on them.
# -----------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:--a}"
DEFAULT_DEVICE="${FLUTTER_DEVICE:-}"

run_unit_and_widget() {
  echo "==> flutter test test/unit test/widget test/widget_test.dart"
  flutter test test/unit test/widget test/widget_test.dart
}

run_e2e() {
  echo "==> flutter test test/e2e"
  flutter test test/e2e
}

run_integration() {
  echo "==> flutter test integration_test -d ${DEFAULT_DEVICE:-<device>}"
  if [ -z "$DEFAULT_DEVICE" ]; then
    echo "No FLUTTER_DEVICE set; starting the default emulator if any..."
    flutter devices
  fi
  flutter test integration_test
}

case "$MODE" in
  -a|--all)   run_unit_and_widget && run_e2e ;;
  -u|--unit)  run_unit_and_widget ;;
  -e|--e2e)   run_e2e ;;
  -i|--integration) run_integration ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: scripts/test.sh [-a|-u|-e|-i]"
    exit 1
    ;;
esac

echo "All requested test suites passed."
