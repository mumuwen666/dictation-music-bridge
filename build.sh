#!/bin/bash
set -euo pipefail

usage() {
    printf 'Usage: %s [--universal] [output.app]\n' "${0##*/}"
    printf '%s\n' 'Defaults to dist/听写音乐联动.app and builds for the current Mac.'
    printf '%s\n' 'Set SIGN_IDENTITY to a Developer ID Application identity for release signing.'
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
architectures=("$(uname -m)")
output=
while [[ $# -gt 0 ]]; do
    case "$1" in
        --universal) architectures=(arm64 x86_64) ;;
        -h|--help) usage; exit 0 ;;
        *.app)
            [[ -z "$output" ]] || fail 'Specify only one output path.'
            output="$1"
            ;;
        *) usage >&2; fail "Unknown argument: $1" ;;
    esac
    shift
done

[[ "$(uname -s)" == Darwin ]] || fail 'A Mac with Xcode or Command Line Tools is required.'
output="${output:-"$project_dir/dist/听写音乐联动.app"}"
[[ "$output" == /* ]] || output="$PWD/$output"
[[ ! -e "$output" && ! -L "$output" ]] || fail "Output already exists: $output"
output_dir="$(dirname -- "$output")"
mkdir -p -- "$output_dir"

build_dir="$(mktemp -d "$output_dir/.dictation-music-bridge.XXXXXXXX")"
trap 'rm -rf -- "$build_dir"' EXIT
bundle="$build_dir/$(basename -- "$output")"
mkdir -p "$bundle/Contents/MacOS"
plist="$bundle/Contents/Info.plist"
cp "$project_dir/Resources/Info.plist" "$plist"
plutil -lint "$plist"
deployment_target="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")"
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
executable="$bundle/Contents/MacOS/$executable_name"
sdk="$(xcrun --sdk macosx --show-sdk-path)"

shopt -s nullglob
sources=("$project_dir"/Sources/DictationMusicBridge/*.swift)
[[ ${#sources[@]} -gt 0 ]] || fail 'No Swift sources were found.'
slices=()
for architecture in "${architectures[@]}"; do
    case "$architecture" in
        arm64|x86_64) ;;
        *) fail "Unsupported architecture: $architecture" ;;
    esac
    slice="$build_dir/$executable_name-$architecture"
    xcrun --sdk macosx swiftc -target "$architecture-apple-macosx$deployment_target" \
        -sdk "$sdk" -O -warnings-as-errors "${sources[@]}" -o "$slice"
    slices+=("$slice")
done

if [[ ${#slices[@]} == 1 ]]; then
    mv -- "${slices[0]}" "$executable"
else
    xcrun lipo -create "${slices[@]}" -output "$executable"
fi
xcrun lipo "$executable" -verify_arch "${architectures[@]}"

if [[ -n "${SIGN_IDENTITY:-}" && "$SIGN_IDENTITY" != '-' ]]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$bundle"
else
    codesign --force --sign - "$bundle"
fi
codesign --verify --strict "$bundle"

[[ ! -e "$output" && ! -L "$output" ]] || fail "Output already exists: $output"
mv -n -- "$bundle" "$output_dir/"
[[ ! -e "$bundle" ]] || fail "Output already exists: $output"
printf 'Built %s (%s)\n' "$output" "${architectures[*]}"
