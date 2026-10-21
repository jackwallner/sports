#!/bin/sh
# Regenerates android/app/src/test/resources/cardart-parity.json from the Swift
# sources, so the Android CardArt tests assert Swift's own URLs, seeds and sports.
# Rerun after changing Sideline/Utilities/CardArt.swift or Shared/Models.
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# The pure half of CardArt.swift: everything before the UIKit image store.
sed -n '1,/MARK: - Loading + cache/p' "$root/Sideline/Utilities/CardArt.swift" \
  | grep -v '^import Shared' | grep -v '^import SwiftUI' > "$work/CardArt.swift"
# Test seam for the private seed function.
sed -i '' 's/    private static func stableSeed/    static func debugSeed(_ text: String) -> UInt32 { stableSeed(text) }\n    private static func stableSeed/' "$work/CardArt.swift"
out="$root/android/app/src/test/resources/cardart-parity.json"
mkdir -p "$(dirname "$out")"
swiftc -o "$work/export" "$root"/Shared/Models/*.swift "$work/CardArt.swift" "$root/scripts/android-export/main.swift"
"$work/export" "$out"
echo "wrote $out"
