#!/usr/bin/env bash
# Compiles the briefing models and JSON coders with a Linux Swift toolchain and
# decodes the live row shape. Usage: run.sh (inside a swift:6.1 container).
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(mktemp -d)"
swiftc -O -o "$out/decode-guard" \
  "$root/Shared/Models/Persona.swift" \
  "$root/Shared/Models/BriefingTag.swift" \
  "$root/Shared/Models/Briefing.swift" \
  "$root/Shared/Services/SidelineJSON.swift" \
  "$root/scripts/decode-guard/main.swift"
"$out/decode-guard"
