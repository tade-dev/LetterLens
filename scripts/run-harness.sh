#!/usr/bin/env bash
# Launch the LetterLens debug harness in the booted Simulator and exit from run.json.
# simctl launch --console always exits 0, even when the app calls exit(1).
#
# Usage:
#   scripts/run-harness.sh LETTERS_DIR OUTPUT_DIR [--txt] [--consent] [--never-upload]
#
# LL_APPCHECK_DEBUG_TOKEN, when set in the environment, is forwarded to the app as
# FIRAAppCheckDebugToken. The script never reads that token from a file and never prints it.

set -euo pipefail

BUNDLE_ID="com.tade.LetterLens-iOS"

usage() {
  echo "Usage: scripts/run-harness.sh LETTERS_DIR OUTPUT_DIR [--txt] [--consent] [--never-upload]" >&2
  exit 2
}

if [[ $# -lt 2 ]]; then
  usage
fi

LETTERS_DIR="$1"
OUTPUT_DIR="$2"
shift 2

TEXT_MODE=0
CONSENT=0
NEVER_UPLOAD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --txt)
      TEXT_MODE=1
      ;;
    --consent)
      CONSENT=1
      ;;
    --never-upload)
      NEVER_UPLOAD=1
      ;;
    *)
      usage
      ;;
  esac
  shift
done

if [[ ! -d "$LETTERS_DIR" ]]; then
  echo "Letters directory not found: $LETTERS_DIR" >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
LETTERS_DIR="$(cd "$LETTERS_DIR" && pwd)"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

export SIMCTL_CHILD_LL_HARNESS_IN="$LETTERS_DIR"
export SIMCTL_CHILD_LL_HARNESS_OUT="$OUTPUT_DIR"

if [[ "$TEXT_MODE" -eq 1 ]]; then
  export SIMCTL_CHILD_LL_HARNESS_SOURCE="txt"
else
  unset SIMCTL_CHILD_LL_HARNESS_SOURCE || true
fi

if [[ "$CONSENT" -eq 1 ]]; then
  export SIMCTL_CHILD_LL_CLOUD_CONSENT="1"
else
  unset SIMCTL_CHILD_LL_CLOUD_CONSENT || true
fi

if [[ "$NEVER_UPLOAD" -eq 1 ]]; then
  export SIMCTL_CHILD_LL_NEVER_UPLOAD="1"
else
  unset SIMCTL_CHILD_LL_NEVER_UPLOAD || true
fi

# Forward an App Check debug token when the caller set it. Do not print the value.
if [[ -n "${LL_APPCHECK_DEBUG_TOKEN:-}" ]]; then
  export SIMCTL_CHILD_FIRAAppCheckDebugToken="$LL_APPCHECK_DEBUG_TOKEN"
else
  unset SIMCTL_CHILD_FIRAAppCheckDebugToken || true
fi

LAUNCH_ARGS=(-LLHarness)
if [[ "$TEXT_MODE" -eq 1 ]]; then
  LAUNCH_ARGS+=(-LLHarnessText)
fi

set +e
xcrun simctl launch --console --terminate-running-process booted "$BUNDLE_ID" "${LAUNCH_ARGS[@]}"
LAUNCH_STATUS=$?
set -e

if [[ "$LAUNCH_STATUS" -ne 0 ]]; then
  echo "simctl launch failed (${LAUNCH_STATUS})." >&2
  exit 2
fi

RUN_JSON="$OUTPUT_DIR/run.json"
if [[ ! -f "$RUN_JSON" ]]; then
  echo "Harness finished without writing ${RUN_JSON}." >&2
  exit 2
fi

# Swift's JSONEncoder pretty-prints integers as `"exit_code" : 1`.
exit_code="$(sed -n 's/.*"exit_code"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$RUN_JSON" | head -n 1)"
if [[ -z "$exit_code" ]]; then
  echo "run.json has no exit_code." >&2
  exit 2
fi

case "$exit_code" in
  0|1|2)
    exit "$exit_code"
    ;;
  *)
    echo "run.json exit_code is ${exit_code}." >&2
    exit 2
    ;;
esac
