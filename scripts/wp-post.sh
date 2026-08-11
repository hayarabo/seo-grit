#!/usr/bin/env bash
# WordPress REST API で記事を下書き入稿し、編集ページの URL を表示する
# 使い方: ユーザーの作業フォルダから
#   <seo-grit>/scripts/wp-post.sh "記事タイトル" articles/<slug>/post.html [status] [--slug <slug>] [--excerpt <text>] [--update <ID>]
#   status は省略時 draft。--slug は URL スラッグ（英単語2〜3語推奨）、
#   --excerpt は抜粋＝meta description の元テキスト。認証情報はカレントディレクトリ（作業フォルダ）の .env から読む。
#   同じスラッグの投稿が既にある場合は重複入稿を防ぐため中断する。上書きするときは --update <ID> を付ける。
set -euo pipefail

SLUG="" EXCERPT="" UPDATE_ID=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --excerpt) EXCERPT="$2"; shift 2 ;;
    --update) UPDATE_ID="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

if [ $# -lt 2 ]; then
  echo "使い方: $0 <タイトル> <本文HTMLファイル> [status] [--slug <slug>] [--excerpt <text>]" >&2
  exit 1
fi

# カレントディレクトリ = ユーザーの作業フォルダが .env と相対パスの基準
if [ ! -f .env ]; then
  echo "カレントディレクトリに .env がありません。作業フォルダで実行し、seo-grit の .env.example を参考に作成してください。" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
source .env
set +a

TITLE="$1" FILE="$2" STATUS="${3:-draft}" SLUG="$SLUG" EXCERPT="$EXCERPT" UPDATE_ID="$UPDATE_ID" python3 - <<'PY'
import base64, json, os, sys, urllib.error, urllib.parse, urllib.request

title = os.environ["TITLE"]
file = os.environ["FILE"]
status = os.environ["STATUS"]
slug = os.environ.get("SLUG", "")
excerpt = os.environ.get("EXCERPT", "")
update_id = os.environ.get("UPDATE_ID", "")
url = os.environ["WP_URL"].rstrip("/")
user = os.environ["WP_USER"]
password = os.environ["WP_APP_PASSWORD"]
token = base64.b64encode(f"{user}:{password}".encode()).decode()

with open(file, encoding="utf-8") as f:
    content = f.read()

def api(path, data=None, method="GET"):
    req = urllib.request.Request(f"{url}/wp-json/wp/v2{path}",
                                 data=json.dumps(data).encode() if data else None, method=method)
    req.add_header("Authorization", f"Basic {token}")
    if data:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as res:
        return json.load(res)

# 同じスラッグの投稿が既にあれば新規作成しない（クラッシュ後の再実行で重複入稿しがちなため）
if slug and not update_id:
    try:
        q = urllib.parse.urlencode({"slug": slug, "status": "draft,pending,future,private,publish", "context": "edit"})
        existing = api(f"/posts?{q}")
    except urllib.error.HTTPError:
        existing = []
    if existing:
        p = existing[0]
        print(f"同じスラッグの投稿が既にあります（ID: {p['id']} / status: {p['status']}）。", file=sys.stderr)
        print(f"編集ページ: {url}/wp-admin/post.php?post={p['id']}&action=edit", file=sys.stderr)
        print(f"この投稿を上書き更新するには --update {p['id']} を付けて再実行してください。", file=sys.stderr)
        sys.exit(1)

payload = {"title": title, "content": content, "status": status}
if slug:
    payload["slug"] = slug
if excerpt:
    payload["excerpt"] = excerpt

try:
    if update_id:
        post = api(f"/posts/{update_id}", payload, "POST")
    else:
        post = api("/posts", payload, "POST")
except urllib.error.HTTPError as e:
    print(f"入稿失敗: HTTP {e.code}", file=sys.stderr)
    print(e.read().decode(errors="replace"), file=sys.stderr)
    sys.exit(1)

post_id = post["id"]
action = "更新" if update_id else "入稿"
print(f"{action}しました（status: {status} / ID: {post_id} / slug: {post.get('slug', '')}）")
print(f"編集ページ: {url}/wp-admin/post.php?post={post_id}&action=edit")
PY
