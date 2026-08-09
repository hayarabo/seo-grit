#!/usr/bin/env bash
# seo-grit のスキルを Claude Code の個人スキル（~/.claude/skills/）に登録する
# 使い方: git clone のあとに一度だけ実行する
#   git clone https://github.com/hayarabo/seo-grit.git && seo-grit/scripts/install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$SKILLS_DIR"

installed=()
for src in "$REPO_DIR"/skills/*/; do
  name="$(basename "$src")"
  ln -sfn "${src%/}" "$SKILLS_DIR/$name"
  installed+=("$name")
done

echo "✅ スキルを登録しました: ${installed[*]}"
echo ""
echo "次のステップ:"
echo "  1. 作業フォルダを作る（seo-grit リポジトリの外ならどこでも）"
echo "     mkdir -p ~/my-media && cd ~/my-media"
echo "  2. そこで Claude Code を起動して /grit-setup と入力する"
