#!/bin/bash
# 사용: build_web.sh <프로젝트 폴더> <출력 폴더> <캐시 폴더>
set -euo pipefail
PROJ="$1"; OUT="$2"; CACHE="$3"
VER="${GODOT_VERSION:-4.7.2}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$CACHE" "$OUT"
BIN="$CACHE/Godot_v${VER}-stable_linux.x86_64"
if [ ! -x "$BIN" ]; then
  echo "고도트 ${VER} 받는 중"
  curl -fsSL -o "$CACHE/godot.zip" "https://github.com/godotengine/godot-builds/releases/download/${VER}-stable/Godot_v${VER}-stable_linux.x86_64.zip"
  (cd "$CACHE" && unzip -o -q godot.zip && rm godot.zip)
  chmod +x "$BIN"
fi
TPL="$HOME/.local/share/godot/export_templates/${VER}.stable"
mkdir -p "$TPL"
if [ ! -f "$CACHE/web_nothreads_release.zip" ]; then
  echo "웹 템플릿 받는 중 (필요한 파일만)"
  python3 "$HERE/get_web_template.py" "$VER" "$CACHE"
fi
cp "$CACHE"/web_*.zip "$TPL/"
cd "$PROJ"
echo "그림 · 소리 불러오기"
"$BIN" --headless --path . --import || true
echo "웹 내보내기"
rm -rf "$OUT"; mkdir -p "$OUT"
"$BIN" --headless --path . --export-release "Web" "$OUT/index.html"
test -f "$OUT/index.pck"
python3 "$HERE/post_export.py" "$OUT"
ls -la "$OUT"
