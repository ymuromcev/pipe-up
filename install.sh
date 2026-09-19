#!/usr/bin/env bash
# Installs the latest Pipe Up into /Applications and opens it.
#
#   curl -fsSL https://raw.githubusercontent.com/ymuromcev/pipe-up/main/install.sh | bash
#
# Options — when piping, pass them after `bash -s --`:
#   --dry-run   do every check, download and verify the app, change nothing: no app
#               is quit, nothing is copied into /Applications, nothing is opened
#   --no-open   install, but don't open Pipe Up afterwards
#
#   curl -fsSL https://raw.githubusercontent.com/ymuromcev/pipe-up/main/install.sh | bash -s -- --dry-run
#
# Why this exists: Pipe Up isn't notarized by Apple. A browser marks what it downloads
# as quarantined, and macOS won't open a quarantined app that isn't notarized until
# you click Open Anyway in System Settings. curl sets no such mark, so an app
# installed this way opens straight away — which means Gatekeeper never looks at it,
# and this script does the checking instead, before anything on the Mac changes:
#
#   - an Apple Silicon Mac on macOS 26 or later;
#   - the disk image's SHA-256 is the one GitHub lists for the release asset (when
#     GitHub's API answers — the fallback route has no digest to compare with);
#   - the app inside is Pipe Up (bundle id app.voiceinput), no file in it has been
#     changed since it was signed, and it was signed with the author's certificate,
#     pinned below. That last check is the one macOS itself relies on to keep the
#     Microphone and Accessibility permissions across updates.
#
# The Sparkle signature on updates isn't used here: checking an EdDSA signature needs a
# tool a stock Mac doesn't have (its openssl is LibreSSL 3.3, without Ed25519).
#
# Environment, for testing:
#   PIPEUP_DMG=path/PipeUp-X.Y.Z.dmg   use this disk image instead of downloading one
#   PIPEUP_APPS_DIR=dir                install into dir instead of /Applications
#
# Everything runs from main, called on the last line: if the download of this script
# is cut short, bash has nothing half-read to execute.
set -euo pipefail

REPO="ymuromcev/pipe-up"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
LATEST_URL="https://github.com/$REPO/releases/latest"
ASSET_PREFIX="https://github.com/$REPO/releases/download/"
BUNDLE_ID="app.voiceinput"
APP_NAME="Pipe Up.app"
MIN_MACOS=26
# SHA-1 of the certificate every Pipe Up release is signed with ("VoiceInput Self
# Signed"), as codesign writes it in the app's designated requirement. A Developer ID
# certificate, once there is one, turns this requirement into
#   identifier "app.voiceinput" and anchor apple generic and certificate leaf[subject.OU] = "<TEAMID>"
CERT_LEAF="ac1c389b459f7403003d06bc2731971adec0e59e"
REQUIREMENT="identifier \"$BUNDLE_ID\" and certificate leaf = H\"$CERT_LEAF\""

APPS_DIR="${PIPEUP_APPS_DIR:-/Applications}"
APPS_DIR="${APPS_DIR%/}"
TARGET="$APPS_DIR/$APP_NAME"
OLD_APP="$APPS_DIR/VoiceInput.app"

DRY_RUN=0
OPEN_APP=1
MACOS=""
NEW_VERSION=""
DMG_URL=""
DMG_DIGEST=""
WORK=""
MOUNT=""
STAGED=""
PREVIOUS=""

say() { printf '%s\n' "$*"; }
step() { printf '==> %s\n' "$*"; }
warn() { printf 'Note: %s\n' "$*" >&2; }
die() {
    printf '\nPipe Up was not installed: %s\n' "$1" >&2
    shift
    local line
    for line in "$@"; do printf '%s\n' "$line" >&2; done
    exit 1
}

usage() {
    cat <<'EOF'
Installs the latest Pipe Up into /Applications and opens it.

  curl -fsSL https://raw.githubusercontent.com/ymuromcev/pipe-up/main/install.sh | bash

Options (when piping: ... | bash -s -- --dry-run):
  --dry-run   check and verify everything, change nothing
  --no-open   install, but don't open Pipe Up afterwards
EOF
}

cleanup() {
    # Interrupted between moving the installed app aside and putting the new one in
    # its place: the one that was there goes back.
    if [ -n "$PREVIOUS" ] && [ -e "$PREVIOUS" ] && [ ! -e "$TARGET" ]; then
        mv "$PREVIOUS" "$TARGET" 2>/dev/null || warn "the previous Pipe Up is at $PREVIOUS"
    fi
    if [ -n "$STAGED" ] && [ -e "$STAGED" ]; then
        rm -rf "$STAGED"
    fi
    if [ -n "$MOUNT" ]; then
        if ! hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 \
                && ! hdiutil detach "$MOUNT" -force -quiet >/dev/null 2>&1; then
            # Deleting a folder with a disk still mounted in it is not something to
            # do on the way out; the temporary folder stays behind instead.
            warn "couldn't eject the Pipe Up disk image mounted at $MOUNT — eject it in Finder"
            return
        fi
    fi
    if [ -n "$WORK" ] && [ -d "$WORK" ]; then
        rm -rf "$WORK"
    fi
}

# True when version $1 is at least $2. Up to three numeric parts; missing ones are 0.
version_ge() {
    local a1 a2 a3 b1 b2 b3 pair a b
    IFS=. read -r a1 a2 a3 _ <<<"$1"
    IFS=. read -r b1 b2 b3 _ <<<"$2"
    for pair in "${a1:-0} ${b1:-0}" "${a2:-0} ${b2:-0}" "${a3:-0} ${b3:-0}"; do
        a="${pair% *}"
        b="${pair#* }"
        [[ "$a" =~ ^[0-9]+$ ]] || a=0
        [[ "$b" =~ ^[0-9]+$ ]] || b=0
        if [ "$a" -gt "$b" ]; then return 0; fi
        if [ "$a" -lt "$b" ]; then return 1; fi
    done
    return 0
}

# Processes running out of the bundle at $1. The full command line starts with the
# bundle's path, and that path is the only thing that tells Pipe Up apart from other
# apps whose binary happens to have the same name.
running_pattern() {
    printf '^%s/Contents/MacOS/' "$(printf '%s' "$1" | sed -e 's/[][\.*^$+?(){}|]/\\&/g')"
}
pids_running_from() {
    pgrep -f "$(running_pattern "$1")" || true
}

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || true
}

check_mac() {
    [ "$(uname -s)" = Darwin ] || die "Pipe Up is a Mac app, and this isn't a Mac."
    # hw.optional.arm64 says 1 on Apple Silicon even in a Terminal running under
    # Rosetta, where uname -m would answer x86_64.
    if [ "$(sysctl -in hw.optional.arm64 2>/dev/null || true)" != 1 ]; then
        die "Pipe Up needs a Mac with Apple Silicon (M1 or later), and this Mac has an Intel processor."
    fi
    MACOS="$(sw_vers -productVersion)"
    if ! version_ge "$MACOS" "$MIN_MACOS"; then
        die "Pipe Up needs macOS $MIN_MACOS or later, and this Mac has macOS $MACOS." \
            "Update macOS in System Settings → General → Software Update, then run this again."
    fi
    if [ "$(id -u)" = 0 ]; then
        die "don't run the installer with sudo or as root." \
            "Run it as yourself: Pipe Up should belong to your account, not to root."
    fi
}

# Whether this account can put an app into $APPS_DIR — checked before the download, so
# nobody waits for one only to be told no. No sudo on purpose: an app installed by
# root belongs to root, and its own updates would then need an administrator too.
check_writable() {
    local problem=""
    if [ ! -d "$APPS_DIR" ]; then
        problem="$APPS_DIR doesn't exist."
    elif [ ! -w "$APPS_DIR" ]; then
        problem="your account can't add apps to $APPS_DIR. Usually that means it isn't an administrator account."
    elif [ -e "$TARGET" ] && [ ! -w "$TARGET" ]; then
        problem="the Pipe Up already in $APPS_DIR belongs to another account, so this one can't replace it."
    fi
    if [ -z "$problem" ]; then
        return 0
    fi
    if [ "$DRY_RUN" = 1 ]; then
        warn "$problem A real install would stop here."
        return 0
    fi
    die "$problem" \
        "The installer doesn't use sudo. Ask an administrator of this Mac to run the same" \
        "command, or download the .dmg from $LATEST_URL and follow the steps there."
}

# Sets DMG_URL, and DMG_DIGEST ("sha256:…") when GitHub gives one.
find_latest() {
    local json="$WORK/latest.json" line="" tag=""
    if [ -x /usr/bin/jq ] && curl -fsSL --proto '=https' --retry 2 \
            -H 'Accept: application/vnd.github+json' -o "$json" "$API_URL" </dev/null 2>/dev/null; then
        tag="$(/usr/bin/jq -r '.tag_name // empty' "$json" 2>/dev/null || true)"
        line="$(/usr/bin/jq -r '
            [.assets[]? | select(.name | test("^PipeUp-[0-9]+\\.[0-9]+\\.[0-9]+\\.dmg$"))][0]
            | select(. != null) | "\(.browser_download_url)\t\(.digest // "")"' "$json" 2>/dev/null || true)"
        if [ -n "$tag" ] && [ -z "$line" ]; then
            die "the latest release on GitHub ($tag) has no Pipe Up disk image." \
                "It may still be uploading. Try again in a few minutes, or see $LATEST_URL"
        fi
        if [ -n "$line" ]; then
            DMG_URL="${line%%$'\t'*}"
            DMG_DIGEST="${line#*$'\t'}"
        fi
    fi
    if [ -z "$DMG_URL" ]; then
        # GitHub's API allows 60 anonymous requests an hour per address. Past that, the
        # releases page still answers: /releases/latest redirects to the newest tag,
        # and the tag names the file.
        step "GitHub's API didn't answer — asking the releases page instead"
        local final
        final="$(curl -fsSL --proto '=https' --retry 2 -o /dev/null -w '%{url_effective}' "$LATEST_URL" </dev/null)" \
            || die "couldn't reach GitHub. Check the internet connection and try again."
        tag="${final##*/tag/}"
        [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
            || die "couldn't work out the latest version from $final"
        DMG_URL="$ASSET_PREFIX$tag/PipeUp-${tag#v}.dmg"
    fi
    case "$DMG_URL" in
        "$ASSET_PREFIX"*) ;;
        *) die "GitHub pointed at an unexpected download address: $DMG_URL" ;;
    esac
}

download() {
    local out="$1" progress=-sS got
    if [ -t 2 ]; then progress=--progress-bar; fi
    step "downloading $DMG_URL"
    curl -fL "$progress" --proto '=https' --retry 3 -o "$out" "$DMG_URL" </dev/null \
        || die "the download failed: $DMG_URL" \
               "Check the internet connection and try again, or download the .dmg from $LATEST_URL"
    case "$DMG_DIGEST" in
        sha256:*)
            got="$(shasum -a 256 "$out" | awk '{ print $1 }')"
            if [ "$got" != "${DMG_DIGEST#sha256:}" ]; then
                die "the downloaded file isn't the one GitHub lists." \
                    "SHA-256 of the download: $got" "GitHub lists:             ${DMG_DIGEST#sha256:}" \
                    "Try again; if it keeps happening, don't install from this network."
            fi
            say "    SHA-256 matches the one GitHub lists"
            ;;
        *)
            say "    no SHA-256 from GitHub to compare with — the signature check below still applies"
            ;;
    esac
}

# Checks the app at $1 and sets NEW_VERSION.
verify_app() {
    local app="$1" id minimum report
    [ -d "$app" ] || die "the disk image has no $APP_NAME inside."
    id="$(plist_value "$app" CFBundleIdentifier)"
    [ "$id" = "$BUNDLE_ID" ] \
        || die "the app in the disk image isn't Pipe Up (its bundle id is \"${id:-none}\", expected $BUNDLE_ID)."
    NEW_VERSION="$(plist_value "$app" CFBundleShortVersionString)"
    minimum="$(plist_value "$app" LSMinimumSystemVersion)"
    if [ -n "$minimum" ] && ! version_ge "$MACOS" "$minimum"; then
        die "Pipe Up $NEW_VERSION needs macOS $minimum or later, and this Mac has macOS $MACOS."
    fi
    # Intact and signed by the author: every file matches the signature, and the
    # signature was made with the pinned certificate. A copy re-signed with any other
    # certificate, whatever its name, fails here.
    if ! report="$(codesign --verify --deep --strict -R "=$REQUIREMENT" "$app" 2>&1)"; then
        die "Pipe Up's signature doesn't check out, so the app may have been tampered with." \
            "What codesign said:" "$report"
    fi
}

main() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            --no-open) OPEN_APP=0 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "unknown option: $arg" ;;
        esac
    done

    say "Pipe Up installer"
    if [ "$DRY_RUN" = 1 ]; then say "(dry run: nothing on this Mac will change)"; fi

    check_mac
    say "    this Mac: Apple Silicon, macOS $MACOS"
    check_writable

    WORK="$(mktemp -d "${TMPDIR:-/tmp}/pipeup-install.XXXXXX")"
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    local dmg
    if [ -n "${PIPEUP_DMG:-}" ]; then
        [ -f "$PIPEUP_DMG" ] || die "PIPEUP_DMG is $PIPEUP_DMG, and there is no such file."
        dmg="$PIPEUP_DMG"
        step "using the local disk image $dmg"
    else
        step "finding the latest release"
        find_latest
        dmg="$WORK/$(basename "$DMG_URL")"
        download "$dmg"
    fi

    step "checking the app"
    MOUNT="$WORK/volume"
    mkdir "$MOUNT"
    if ! hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$MOUNT" "$dmg" \
            </dev/null >/dev/null 2>"$WORK/hdiutil.log"; then
        MOUNT=""
        die "couldn't open the disk image — the file may be damaged." "$(cat "$WORK/hdiutil.log")"
    fi
    verify_app "$MOUNT/$APP_NAME"
    say "    Pipe Up $NEW_VERSION ($BUNDLE_ID): signed with the author's certificate, nothing changed since"

    local installed_version="" installed_id running old_running=""
    if [ -e "$TARGET" ]; then
        installed_id="$(plist_value "$TARGET" CFBundleIdentifier)"
        [ "$installed_id" = "$BUNDLE_ID" ] \
            || die "$TARGET is some other app (bundle id \"${installed_id:-none}\"), so it won't be replaced." \
                   "Move it elsewhere and run this again."
        installed_version="$(plist_value "$TARGET" CFBundleShortVersionString)"
        installed_version="${installed_version:-?}"
    fi
    running="$(pids_running_from "$TARGET" | tr '\n' ' ')"
    running="${running% }"
    if [ -e "$OLD_APP" ] && [ -n "$(pids_running_from "$OLD_APP")" ]; then
        old_running=1
    fi

    if [ "$DRY_RUN" = 1 ]; then
        say
        say "Dry run finished, nothing was changed. A real run would:"
        if [ -n "$running" ]; then
            say "  - quit the running Pipe Up (process $running)"
        fi
        if [ -n "$installed_version" ]; then
            say "  - replace Pipe Up $installed_version at $TARGET with Pipe Up $NEW_VERSION"
        else
            say "  - copy Pipe Up $NEW_VERSION to $TARGET"
        fi
        if [ -e "$OLD_APP" ]; then
            say "  - leave the older VoiceInput at $OLD_APP where it is"
        fi
        if [ -n "$old_running" ]; then
            say "  - not open Pipe Up: VoiceInput is running, and both would answer the same key"
        elif [ "$OPEN_APP" = 1 ]; then
            say "  - open Pipe Up"
        fi
        exit 0
    fi

    if [ -n "$running" ]; then
        step "quitting the running Pipe Up"
        # A plain TERM, not an AppleScript quit: that needs the Automation permission
        # and would put a system prompt in the middle of the install. A menu-bar app
        # with nothing unsaved takes a TERM without complaint.
        pkill -TERM -f "$(running_pattern "$TARGET")" || true
        local _
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            if [ -z "$(pids_running_from "$TARGET")" ]; then break; fi
            sleep 1
        done
        [ -z "$(pids_running_from "$TARGET")" ] \
            || die "Pipe Up is still running." "Quit it from its menu bar icon, then run this again."
    fi

    if [ -n "$installed_version" ]; then
        step "replacing Pipe Up $installed_version with $NEW_VERSION"
    else
        step "copying Pipe Up $NEW_VERSION to $APPS_DIR"
    fi
    # Staged next to the target, so the last step is a rename on the same disk: at no
    # point is there half an app where Pipe Up should be.
    STAGED="$APPS_DIR/.Pipe Up.app.installing-$$"
    ditto "$MOUNT/$APP_NAME" "$STAGED" || die "couldn't copy Pipe Up into $APPS_DIR."
    verify_app "$STAGED"
    if [ -e "$TARGET" ]; then
        PREVIOUS="$APPS_DIR/.Pipe Up.app.previous-$$"
        mv "$TARGET" "$PREVIOUS" || die "couldn't move the installed Pipe Up aside to replace it."
    fi
    if ! mv "$STAGED" "$TARGET"; then
        if [ -n "$PREVIOUS" ] && mv "$PREVIOUS" "$TARGET"; then
            PREVIOUS=""
            die "couldn't put Pipe Up into $APPS_DIR. The version you had is back in place."
        fi
        die "couldn't put Pipe Up into $APPS_DIR."
    fi
    STAGED=""
    if [ -n "$PREVIOUS" ]; then
        # The version just replaced — Pipe Up's own old copy, nothing of the user's.
        if ! rm -rf "$PREVIOUS"; then
            warn "couldn't remove the replaced version at $PREVIOUS — move it to the Trash"
        fi
        PREVIOUS=""
    fi

    say
    say "Pipe Up $NEW_VERSION is installed: $TARGET"
    if [ -e "$OLD_APP" ]; then
        local old_version
        old_version="$(plist_value "$OLD_APP" CFBundleShortVersionString)"
        say
        say "You also have VoiceInput ${old_version:+$old_version }at $OLD_APP. That's Pipe Up's"
        say "old name, and the installer leaves it alone: once Pipe Up works for you,"
        say "move VoiceInput to the Trash."
        if [ -n "$old_running" ]; then
            say
            say "VoiceInput is running right now, and both apps would answer the same key."
            say "Quit VoiceInput from its menu bar icon, then open Pipe Up from $APPS_DIR."
            exit 0
        fi
    fi
    if [ "$OPEN_APP" = 1 ]; then
        open "$TARGET"
        say
        say "Pipe Up is starting: look for its icon in the menu bar. On first launch a"
        say "short guide opens, and macOS asks for the Microphone and Accessibility."
    else
        say "Open it from $APPS_DIR when you're ready."
    fi
}

main "$@"
