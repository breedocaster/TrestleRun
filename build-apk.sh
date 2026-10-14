#!/usr/bin/env bash
# Build a debug-signed APK of Trestle Run on Arch Linux; optionally install it over USB.
#
#   ./build-apk.sh            build only  -> build/trestle-run.apk
#   ./build-apk.sh --install  build, then `adb install -r` to the connected phone
#
# Safe to re-run: every step skips work that's already done.
# Downloads on first run: Godot export templates (large, one time) and Google's Android
# command-line tools + platform-tools + build-tools.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"   # Godot's default SDK path on Linux
JDK="/usr/lib/jvm/java-17-openjdk"
BUILD_TOOLS="35.0.1"                        # version the Godot 4.7 docs specify
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/trestle-run"
OUT="$PROJECT_DIR/build/trestle-run.apk"
INSTALL=0
[[ "${1:-}" == "--install" ]] && INSTALL=1

step() { printf '\n==> %s\n' "$*"; }

step "Packages (godot, JDK 17, unzip, curl)"
sudo pacman -S --needed --noconfirm godot jdk17-openjdk unzip curl

# Export templates must match the editor version exactly, e.g. 4.7.2.stable.arch_linux
# -> folder 4.7.2.stable, release tag 4.7.2-stable.
VER_RAW="$(godot --headless --version | tail -n1)"
if [[ "$VER_RAW" =~ ^([0-9]+\.[0-9]+(\.[0-9]+)?)\.([a-z]+[0-9]*) ]]; then
	NUM="${BASH_REMATCH[1]}"
	STATUS="${BASH_REMATCH[3]}"
else
	echo "Couldn't parse Godot version from: $VER_RAW" >&2
	exit 1
fi
TAG="${NUM}-${STATUS}"
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${NUM}.${STATUS}"

step "Export templates for Godot $TAG"
if [[ ! -f "$TPL_DIR/android_debug.apk" ]]; then
	mkdir -p "$CACHE" "$TPL_DIR"
	TPZ="$CACHE/Godot_v${TAG}_export_templates.tpz"
	if [[ ! -f "$TPZ" ]]; then
		curl -fL --retry 3 -o "$TPZ.part" \
			"https://github.com/godotengine/godot/releases/download/${TAG}/Godot_v${TAG}_export_templates.tpz"
		mv "$TPZ.part" "$TPZ"
	fi
	# Only the Android pieces are needed; skip the other platforms' templates.
	unzip -o -j "$TPZ" 'templates/android_*' 'templates/version.txt' -d "$TPL_DIR"
else
	echo "already installed in $TPL_DIR"
fi

step "Android SDK in $SDK"
export JAVA_HOME="$JDK"
SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$SDKMANAGER" ]]; then
	mkdir -p "$CACHE" "$SDK/cmdline-tools"
	ZIP_NAME=""
	for idx in repository2-3.xml repository2-1.xml; do
		ZIP_NAME="$(curl -fsSL "https://dl.google.com/android/repository/$idx" 2>/dev/null \
			| grep -oE 'commandlinetools-linux-[0-9]+_latest\.zip' | sort -V | tail -n1 || true)"
		[[ -n "$ZIP_NAME" ]] && break
	done
	if [[ -z "$ZIP_NAME" ]]; then
		echo "Couldn't find the command-line tools in Google's index." >&2
		echo "Download 'Command line tools only' for Linux from https://developer.android.com/studio" >&2
		echo "and unzip it so this exists: $SDKMANAGER" >&2
		exit 1
	fi
	curl -fL --retry 3 -o "$CACHE/$ZIP_NAME" "https://dl.google.com/android/repository/$ZIP_NAME"
	rm -rf "$CACHE/cmdline-tools" "$SDK/cmdline-tools/latest"
	unzip -q "$CACHE/$ZIP_NAME" -d "$CACHE"
	mv "$CACHE/cmdline-tools" "$SDK/cmdline-tools/latest"
fi
# Accept SDK licenses non-interactively (`yes` exits on SIGPIPE, hence `|| true`).
yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses > /dev/null || true
# Godot's prebuilt-template export only checks for adb (platform-tools) and apksigner (build-tools).
"$SDKMANAGER" --sdk_root="$SDK" "platform-tools" "build-tools;$BUILD_TOOLS"
export ANDROID_HOME="$SDK"

step "Debug keystore"
KS="$HOME/.android/debug.keystore"
if [[ ! -f "$KS" ]]; then
	mkdir -p "$(dirname "$KS")"
	"$JDK/bin/keytool" -genkeypair -keystore "$KS" -storepass android -alias androiddebugkey \
		-keypass android -keyalg RSA -keysize 2048 -validity 9999 -dname "CN=Android Debug,O=Android,C=US"
else
	echo "using $KS"
fi
# Godot reads these instead of the preset's keystore fields.
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KS"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

step "Import project and point Godot at the JDK + SDK"
godot --headless --path "$PROJECT_DIR" --import
# JAVA_HOME/ANDROID_HOME only seed Godot's defaults; an existing editor settings file wins,
# so pin the two paths there too.
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-$(cut -d. -f1-2 <<< "$NUM").tres"
set_cfg() {
	[[ -f "$CFG" ]] || return 0
	if grep -q "^$1 = " "$CFG"; then
		sed -i "s|^$1 = .*|$1 = \"$2\"|" "$CFG"
	else
		printf '%s = "%s"\n' "$1" "$2" >> "$CFG"
	fi
}
set_cfg "export/android/java_sdk_path" "$JDK"
set_cfg "export/android/android_sdk_path" "$SDK"

step "Export APK"
mkdir -p "$PROJECT_DIR/build"
rm -f "$OUT"
godot --headless --path "$PROJECT_DIR" --export-debug "Android" "$OUT"
if [[ ! -f "$OUT" ]]; then
	echo "Export failed; the Godot output above says why." >&2
	exit 1
fi
ls -lh "$OUT"

if (( INSTALL )); then
	step "Install to phone"
	ADB="$SDK/platform-tools/adb"
	if ! "$ADB" get-state > /dev/null 2>&1; then
		echo "No device. Enable USB debugging on the phone, plug it in, accept the prompt, re-run." >&2
		exit 1
	fi
	"$ADB" install -r "$OUT"
fi
