#!/usr/bin/env bash
# WordPress 接続テスト: 疎通・認証・有効テーマ・既存記事の取得を確認する
# 使い方: ユーザーの作業フォルダから <seo-grit>/scripts/wp-check.sh
#   認証情報はカレントディレクトリ（作業フォルダ）の .env から読む。
set -euo pipefail

if [ ! -f .env ]; then
  echo "カレントディレクトリに .env がありません。作業フォルダで実行し、seo-grit の .env.example を参考に作成してください。" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
source .env
set +a

python3 - <<'PY'
import base64, json, os, sys, urllib.error, urllib.request

url = os.environ["WP_URL"].rstrip("/")
user = os.environ["WP_USER"]
password = os.environ["WP_APP_PASSWORD"]
token = base64.b64encode(f"{user}:{password}".encode()).decode()

def get(path, auth=False):
    req = urllib.request.Request(f"{url}/wp-json{path}")
    if auth:
        req.add_header("Authorization", f"Basic {token}")
    with urllib.request.urlopen(req) as res:
        return json.load(res)

# 1. 疎通
try:
    site = get("/")
except Exception as e:
    print(f"NG: サイトに到達できません（{url}/wp-json）: {e}", file=sys.stderr)
    print("WP_URL が正しいか（末尾スラッシュなし・/blog 等のパス込みか）を確認してください。", file=sys.stderr)
    sys.exit(1)
print(f"OK: サイト疎通 — {site.get('name', '(名称不明)')}")

# 2. 認証
try:
    me = get("/wp/v2/users/me", auth=True)
except urllib.error.HTTPError as e:
    print(f"NG: 認証失敗（HTTP {e.code}）。WP_USER / WP_APP_PASSWORD を確認してください。", file=sys.stderr)
    print("アプリケーションパスワードはスペース込みでそのまま貼り付けます。", file=sys.stderr)
    sys.exit(1)
print(f"OK: 認証成功 — ユーザー: {me.get('name')}")

# 3. 有効テーマ
try:
    themes = get("/wp/v2/themes?status=active", auth=True)
    if themes:
        name = themes[0].get("name", {}).get("rendered", "?")
        slug = themes[0].get("stylesheet", "")
        print(f"OK: 有効テーマ — {name} ({slug})")
except Exception:
    print("注意: テーマ情報を取得できませんでした（権限不足でも入稿には支障ありません）")

# 4. 既存記事（レギュレーション学習用）
try:
    posts = get("/wp/v2/posts?per_page=5&status=publish", auth=True)
    print(f"OK: 公開記事 {len(posts)} 件を取得（レギュレーションの学習素材になります）")
    for p in posts:
        print(f"  - {p.get('title', {}).get('rendered', '(無題)')}")
except Exception:
    print("注意: 記事一覧を取得できませんでした")

print("接続テスト完了 🎉 入稿できる状態です。")
PY
