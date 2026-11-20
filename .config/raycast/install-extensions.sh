#!/usr/bin/env bash
# extensions-src の自作拡張をすべてビルドして Raycast に入れる
# npm は入れていないので nix shell の nodejs_24 で動かす
# 使い方: ./install-extensions.sh [拡張名...]  (省くと全部)
set -euo pipefail

src_dir="$(cd "$(dirname "$0")" && pwd)/extensions-src"

if [ "$#" -gt 0 ]; then
  names=("$@")
else
  names=()
  for dir in "$src_dir"/*/; do
    names+=("$(basename "$dir")")
  done
fi

for name in "${names[@]}"; do
  echo "==> $name"
  (
    cd "$src_dir/$name"
    # ray build の既定 (-e dev) は ~/.config/raycast/extensions に出力し、Raycast がそこから読み込む
    nix shell nixpkgs#nodejs_24 -c sh -c 'npm ci --no-audit --no-fund && npx ray build -I'
  )
done
