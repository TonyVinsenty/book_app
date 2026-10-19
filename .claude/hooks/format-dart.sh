#!/usr/bin/env bash
# PostToolUse hook: run `dart format` on a .dart file right after Edit/Write.
# Reads the tool call JSON from stdin; never blocks the edit (always exit 0).
input=$(cat)
file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
file=${file//\\//}
case "$file" in
  *.g.dart | */l10n/generated/*) exit 0 ;;
  *.dart) [ -f "$file" ] && dart format "$file" > /dev/null 2>&1 ;;
esac
exit 0
