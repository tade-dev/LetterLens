#!/usr/bin/env bash
# Point the app at a different Firebase project, and put it back afterwards.
#
# The harness needs this when the usual project's model is unavailable and a
# sponsored hackathon project has its own quota. Only the plist changes: the
# bundle id, the prompts and the bundled Remote Config defaults stay as they are,
# and the harness skips fetchAndActivate, so no template needs deploying.
#
# Usage:
#   scripts/use-firebase-config.sh /path/to/GoogleService-Info.plist   install it
#   scripts/use-firebase-config.sh --restore                           put the original back
#   scripts/use-firebase-config.sh --which                             say which project is active
#
# The live plist is gitignored. Backups live outside the repo, in
# ~/.letterlens/configs, so a swap can never be committed.

set -euo pipefail

LIVE="LetterLens-iOS/GoogleService-Info.plist"
STORE="${HOME}/.letterlens/configs"
BACKUP="${STORE}/GoogleService-Info.original.plist"

if [[ ! -d LetterLens-iOS ]]; then
  echo "error: run this from the repository root." >&2
  exit 2
fi

read_key() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || echo "?"
}

describe() {
  local file="$1"
  printf '  project: %s\n  bundle:  %s\n' \
    "$(read_key "$file" PROJECT_ID)" \
    "$(read_key "$file" BUNDLE_ID)"
}

case "${1:-}" in
  --which)
    if [[ -f "$LIVE" ]]; then
      echo "Active Firebase config:"
      describe "$LIVE"
      # An if, not `&&`: a false test is the last command and `set -e` would exit 1.
      if [[ -f "$BACKUP" ]]; then
        echo "  (an original is saved at ${BACKUP})"
      fi
    else
      echo "No ${LIVE}. The app builds, logs the absence, and skips FirebaseApp.configure()."
    fi
    ;;
  --restore)
    if [[ ! -f "$BACKUP" ]]; then
      echo "error: nothing to restore; ${BACKUP} does not exist." >&2
      exit 1
    fi
    cp "$BACKUP" "$LIVE"
    rm -f "$BACKUP"
    echo "Restored the original config:"
    describe "$LIVE"
    echo "Rebuild and reinstall before the next run."
    ;;
  "" | --help | -h)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    NEW="$1"
    if [[ ! -f "$NEW" ]]; then
      echo "error: ${NEW} does not exist." >&2
      exit 2
    fi
    if [[ "$(read_key "$NEW" PROJECT_ID)" == "?" ]]; then
      echo "error: ${NEW} is not a GoogleService-Info.plist (no PROJECT_ID)." >&2
      exit 2
    fi
    want="$(read_key "$NEW" BUNDLE_ID)"
    if [[ "$want" != "com.tade.LetterLens-iOS" ]]; then
      echo "error: that plist is for bundle id '${want}'." >&2
      echo "       Register the iOS app as com.tade.LetterLens-iOS and download it again." >&2
      exit 2
    fi
    mkdir -p "$STORE"
    # Back up only the first time, so repeated swaps cannot lose the original.
    if [[ -f "$LIVE" && ! -f "$BACKUP" ]]; then
      cp "$LIVE" "$BACKUP"
      echo "Saved the current config to ${BACKUP}"
    fi
    cp "$NEW" "$LIVE"
    echo "Now using:"
    describe "$LIVE"
    echo
    echo "Next: rebuild and reinstall, then run one letter before the full 15."
    echo "A new project needs its own App Check debug token: run once, find"
    echo "[AppCheckCore][I-GAC004001] in the Xcode console, and register it."
    ;;
esac
