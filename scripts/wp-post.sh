#!/usr/bin/env bash
# WordPress REST API で記事を下書き入稿し、編集ページの URL を表示する
# 使い方: scripts/wp-post.sh "記事タイトル" data/articles/<slug>/post.html [status]
#   status は省略時 draft。認証情報は .env（.env.example 参照）から読む。
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "使い方: $0 <タイトル> <本文HTMLファイル> [status]" >&2
  exit 1
fi

# リポジトリルートで実行する（.env と相対パスの基準）
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo ".env がありません。cp .env.example .env で作成して接続情報を記入してください。" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
source .env
set +a

TITLE="$1" FILE="$2" STATUS="${3:-draft}" python3 - <<'PY'
import base64, json, os, sys, urllib.error, urllib.request

title = os.environ["TITLE"]
file = os.environ["FILE"]
status = os.environ["STATUS"]
url = os.environ["WP_URL"].rstrip("/")
user = os.environ["WP_USER"]
password = os.environ["WP_APP_PASSWORD"]

with open(file, encoding="utf-8") as f:
    content = f.read()

data = json.dumps({"title": title, "content": content, "status": status}).encode()
req = urllib.request.Request(f"{url}/wp-json/wp/v2/posts", data=data, method="POST")
req.add_header("Content-Type", "application/json")
token = base64.b64encode(f"{user}:{password}".encode()).decode()
req.add_header("Authorization", f"Basic {token}")

try:
    with urllib.request.urlopen(req) as res:
        post = json.load(res)
except urllib.error.HTTPError as e:
    print(f"入稿失敗: HTTP {e.code}", file=sys.stderr)
    print(e.read().decode(errors="replace"), file=sys.stderr)
    sys.exit(1)

post_id = post["id"]
print(f"入稿しました（status: {status} / ID: {post_id}）")
print(f"編集ページ: {url}/wp-admin/post.php?post={post_id}&action=edit")
PY
