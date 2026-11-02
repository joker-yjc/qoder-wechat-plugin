#!/usr/bin/env bash
# 把插件打包成市场 / GitHub Release 用的 zip。
# 规范硬性要求：ZIP 根目录必须就是插件根目录（.qoder-plugin/ 直接在根下），
# 且不能混入 node_modules、dist 等本地产物，所以文件清单以 git 为准。
set -euo pipefail
cd "$(dirname "$0")/.."

command -v zip >/dev/null 2>&1 || {
  echo "缺少 zip 命令。macOS 自带；Windows 请在 Git Bash 里先装 zip，或改用 PowerShell 的 Compress-Archive。" >&2
  exit 1
}

MANIFEST='.qoder-plugin/plugin.json'
NAME=$(node -p "JSON.parse(require('fs').readFileSync('$MANIFEST','utf8')).name")
VERSION=$(node -p "JSON.parse(require('fs').readFileSync('$MANIFEST','utf8')).version")
OUT="dist/${NAME}-${VERSION}.zip"

rm -rf dist
mkdir -p dist
git ls-files --cached --others --exclude-standard | zip -X -q "$OUT" -@

# 用 grep -c 而不是 grep -q：后者命中即退出，会让上游 unzip 收到 SIGPIPE，
# 在 pipefail 下把「找到了」误判成「命令失败」。
LIST=$(unzip -Z1 "$OUT")

if [ "$(printf '%s\n' "$LIST" | grep -cxF -- "$MANIFEST")" -ne 1 ]; then
  echo "打包失败：zip 根目录缺少 $MANIFEST" >&2
  exit 1
fi
if [ "$(printf '%s\n' "$LIST" | grep -cE '(^|/)(node_modules|dist)/')" -gt 0 ]; then
  echo "打包失败：zip 里混入了本地依赖或构建产物" >&2
  exit 1
fi

echo "已生成 $OUT"
echo "  条目：$(printf '%s\n' "$LIST" | wc -l | tr -d ' ') 个文件"
echo "  大小：$(wc -c < "$OUT" | tr -d ' ') 字节"
echo "  sha256：$(shasum -a 256 "$OUT" | cut -d' ' -f1)"
