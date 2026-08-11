#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SimGate full project check.
#
# Runs, in order: static analysis, formatting check, host test suites
# (unit + widget + e2e HTTP), and a native Kotlin compile. Optionally builds
# a debug APK.
#
# Usage:
#   scripts/check.sh           # analyze + format + tests + kotlin compile
#   scripts/check.sh --apk     # also build a debug APK
#   scripts/check.sh --no-kotlin  # skip the Android native compile
#
# Any failing step aborts with a non-zero exit code.
# -----------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_APK=false
SKIP_KOTLIN=false
for arg in "$@"; do
  case "$arg" in
    --apk) BUILD_APK=true ;;
    --no-kotlin) SKIP_KOTLIN=true ;;
    *)
      echo "Unknown flag: $arg"
      echo "Usage: scripts/check.sh [--apk] [--no-kotlin]"
      exit 1
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------
cat <<'EOF'

   .dMMMb  dMP dMMMMMMMMb        .aMMMMP .aMMMb dMMMMMMP dMMMMMP
  dMP" VP amr dMP"dMP"dMP       dMP"    dMP"dMP   dMP   dMP
  VMMMb  dMP dMP dMP dMP       dMP MMP"dMMMMMP   dMP   dMMMP
dP .dMP dMP dMP dMP dMP       dMP.dMP dMP dMP   dMP   dMP
VMMMP" dMP dMP dMP dMP        VMMMP" dMP dMP   dMP   dMMMMMP

EOF

echo "============================================================"
echo " SimGate full project check"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

FAILED=0
STEP=0

step() {
  STEP=$((STEP + 1))
  echo
  echo "------------------------------------------------------------"
  echo " [$STEP] $1"
  echo "------------------------------------------------------------"
}

fail() {
  echo
  echo "*** FAILED: $1"
  FAILED=1
}

# -----------------------------------------------------------------------------
# 1. Static analysis
# -----------------------------------------------------------------------------
step "Static analysis (flutter analyze)"
if ! flutter analyze; then
  fail "flutter analyze"
else
  echo "OK: no analyzer issues."
fi

# -----------------------------------------------------------------------------
# 2. Formatting
# -----------------------------------------------------------------------------
step "Formatting (dart format --set-exit-if-changed)"
if ! dart format --set-exit-if-changed lib test integration_test; then
  fail "dart format"
else
  echo "OK: all files formatted."
fi

# -----------------------------------------------------------------------------
# 3. Tests (unit + widget + e2e)
# -----------------------------------------------------------------------------
step "Tests (unit + widget + e2e)"
if ! flutter test test/unit test/widget test/widget_test.dart test/e2e; then
  fail "flutter test"
else
  echo "OK: all host-runnable tests passed."
fi

# -----------------------------------------------------------------------------
# 4. Native Android compile
# -----------------------------------------------------------------------------
if [ "$SKIP_KOTLIN" = false ]; then
  step "Android native compile (gradlew compileDebugKotlin)"
  # Gradle needs a JDK; prefer JAVA_HOME, then Android Studio's bundled JBR.
  if [ -z "${JAVA_HOME:-}" ] && [ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    echo "Using Android Studio JBR: $JAVA_HOME"
  fi
  if ! (cd android && ./gradlew compileDebugKotlin); then
    fail "gradlew compileDebugKotlin"
  else
    echo "OK: Kotlin compiles cleanly."
  fi
else
  echo "Skipping Kotlin compile (--no-kotlin)."
fi

# -----------------------------------------------------------------------------
# 5. Optional debug APK
# -----------------------------------------------------------------------------
if [ "$BUILD_APK" = true ]; then
  step "Debug APK (flutter build apk --debug)"
  if ! flutter build apk --debug; then
    fail "flutter build apk --debug"
  else
    echo "OK: APK built."
  fi
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo
echo "============================================================"
if [ "$FAILED" -eq 0 ]; then
  echo " ALL CHECKS PASSED ✔"
else
  echo " CHECKS FAILED ✘"
fi
echo "============================================================"
exit "$FAILED"
