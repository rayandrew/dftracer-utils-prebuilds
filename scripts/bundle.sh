#!/usr/bin/env bash

set -euo pipefail

PREFIX="${1:?usage: bundle.sh <install-prefix>}"
BIN="$PREFIX/bin"
LIB="$PREFIX/lib"
mkdir -p "$LIB"

bins=()
while IFS= read -r b; do
  bins+=("$b")
done < <(find "$BIN" -maxdepth 1 -type f -perm -u+x 2>/dev/null | sort)
if [ "${#bins[@]}" -eq 0 ]; then
  echo "no executables found in $BIN" >&2
  exit 1
fi
echo "tools: ${#bins[@]}"

case "$(uname -s)" in
Darwin)
  is_external() {
    case "$1" in
    @* | /usr/lib/* | /System/*) return 1 ;;
    *) return 0 ;;
    esac
  }
  changed=1
  while [ "$changed" = 1 ]; do
    changed=0
    refs=("${bins[@]}")
    for l in "$LIB"/*.dylib; do [ -f "$l" ] && refs+=("$l"); done
    for r in "${refs[@]}"; do
      while IFS= read -r dep; do
        is_external "$dep" || continue
        name="$(basename "$dep")"
        if [ ! -e "$LIB/$name" ]; then
          cp -L "$dep" "$LIB/$name" # -L: copy the real file, not the symlink
          chmod u+w "$LIB/$name"
          install_name_tool -id "@rpath/$name" "$LIB/$name"
          changed=1
        fi
        install_name_tool -change "$dep" "@rpath/$name" "$r" 2>/dev/null || true
      done < <(otool -L "$r" | tail -n +2 | awk '{print $1}')
    done
  done
  ;;
Linux)
  is_system() {
    case "$1" in
    /lib/* | /usr/lib/* | /lib64/* | /usr/lib64/*) return 0 ;;
    *) return 1 ;;
    esac
  }
  for b in "${bins[@]}"; do
    ldd "$b" 2>/dev/null | awk '/=> \//{print $3}' | while read -r lib; do
      is_system "$lib" || cp -n "$lib" "$LIB/" 2>/dev/null || true
    done
    patchelf --set-rpath '$ORIGIN/../lib' "$b"
  done
  for l in "$LIB"/*.so*; do
    [ -f "$l" ] || continue
    ldd "$l" 2>/dev/null | awk '/=> \//{print $3}' | while read -r lib; do
      is_system "$lib" || cp -n "$lib" "$LIB/" 2>/dev/null || true
    done
    patchelf --set-rpath '$ORIGIN' "$l" 2>/dev/null || true
  done
  ;;
*)
  echo "unsupported platform: $(uname -s)" >&2
  exit 1
  ;;
esac

echo "relocatable bundle ready at $PREFIX"
ls -la "$BIN" "$LIB" 2>/dev/null | head -60 || true
