#!/usr/bin/env bash
# Builds the game into build/release/ for the given platforms.
#
#   tools/export.sh [android] [windows] [linux] [web]     (default: all four)
#
# Environment:
#   GODOT          Godot 4.7.2 binary with export templates installed (default: godot)
#   VERSION        version like 0.2.0 or 0.2.0-beta.1; stamped into the project and
#                  the file names (default: config/version from project.godot)
#   ANDROID_HOME   Android SDK with platform-tools and build-tools (Android only)
#   JAVA_HOME      JDK 17 or newer (Android only)
#   ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_ALIAS, ANDROID_KEYSTORE_PASSWORD
#                  optional release key. Without it the APK is a debug build signed
#                  with the shared test key in tools/android/debug.keystore.
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/build/release"
PLATFORMS=("$@")
if [ ${#PLATFORMS[@]} -eq 0 ]; then
  PLATFORMS=(android windows linux web)
fi

current_version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
VERSION="${VERSION:-$current_version}"
VERSION="${VERSION#v}"
if ! [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z.]+)?$ ]]; then
  echo "VERSION must look like 1.2.3 or 1.2.3-beta.1, got '$VERSION'" >&2
  exit 1
fi
major="${BASH_REMATCH[1]}"; minor="${BASH_REMATCH[2]}"; patch="${BASH_REMATCH[3]}"
# Android needs a growing integer version code: 1.2.3 -> 10203.
version_code=$((major * 10000 + minor * 100 + patch))
numeric="$major.$minor.$patch"

echo "Building Pass the Plate! $VERSION (Android version code $version_code)"
sed -i "s/^config\/version=.*/config\/version=\"$VERSION\"/" project.godot
sed -i "s/^version\/name=.*/version\/name=\"$VERSION\"/; s/^version\/code=.*/version\/code=$version_code/" export_presets.cfg
sed -i "s/^application\/file_version=.*/application\/file_version=\"$numeric.0\"/; s/^application\/product_version=.*/application\/product_version=\"$numeric.0\"/" export_presets.cfg

rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

export_preset() {  # mode preset path
  local log
  log="$("$GODOT" --headless --path . "--export-$1" "$2" "$3" 2>&1)" || true
  if [ ! -s "$3" ] || grep -qE "^ERROR:|SCRIPT ERROR" <<<"$log"; then
    echo "$log" >&2
    echo "Export of '$2' failed." >&2
    exit 1
  fi
}

# Points Godot's editor settings at the Android SDK and JDK.
configure_android_sdk() {
  : "${ANDROID_HOME:?set ANDROID_HOME to the Android SDK}" "${JAVA_HOME:?set JAVA_HOME to a JDK}"
  local settings
  settings="$(ls "$HOME"/.config/godot/editor_settings-4.*.tres 2>/dev/null | head -1)"
  if [ -z "$settings" ]; then
    echo "Godot editor settings not found (the import step should create them)." >&2
    exit 1
  fi
  for entry in "android_sdk_path=$ANDROID_HOME" "java_sdk_path=$JAVA_HOME"; do
    local key="export/android/${entry%%=*}" value="${entry#*=}"
    if grep -q "^$key = " "$settings"; then
      sed -i "s|^$key = .*|$key = \"$value\"|" "$settings"
    else
      echo "$key = \"$value\"" >> "$settings"
    fi
  done
}

for platform in "${PLATFORMS[@]}"; do
  case "$platform" in
    android)
      configure_android_sdk
      export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$ROOT/tools/android/debug.keystore"
      export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
      export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
      apk="$OUT/PassThePlate-$VERSION-android.apk"
      rm -f "$apk.idsig"
      if [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
        keystore="$(mktemp --suffix=.keystore)"
        base64 -d <<<"$ANDROID_KEYSTORE_BASE64" > "$keystore"
        export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore"
        export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${ANDROID_KEYSTORE_ALIAS:?set ANDROID_KEYSTORE_ALIAS}"
        export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD:?set ANDROID_KEYSTORE_PASSWORD}"
        export_preset release Android "$apk"
        rm -f "$keystore"
      else
        echo "No release key: building a debug APK signed with the shared test key."
        export_preset debug Android "$apk"
      fi
      ;;
    windows)
      mkdir -p build/windows
      export_preset release Windows build/windows/PassThePlate.exe
      (cd build/windows && zip -q -r "$OUT/PassThePlate-$VERSION-windows.zip" .)
      ;;
    linux)
      mkdir -p build/linux
      export_preset release Linux build/linux/PassThePlate.x86_64
      tar -czf "$OUT/PassThePlate-$VERSION-linux.tar.gz" -C build/linux .
      ;;
    web)
      mkdir -p build/web
      export_preset release Web build/web/index.html
      (cd build/web && zip -q -r "$OUT/PassThePlate-$VERSION-web.zip" .)
      ;;
    *)
      echo "Unknown platform '$platform'" >&2
      exit 1
      ;;
  esac
  echo "Built $platform"
done

rm -f "$OUT"/*.idsig
(cd "$OUT" && sha256sum * > SHA256SUMS.txt)
ls -la "$OUT"
