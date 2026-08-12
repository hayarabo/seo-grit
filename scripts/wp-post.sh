#!/usr/bin/env bash
# WordPress REST API で記事を下書き入稿し、編集ページの URL を表示する
# 使い方: ユーザーの作業フォルダから
#   <seo-grit>/scripts/wp-post.sh "記事タイトル" articles/<slug>/post.html [status] [--slug <slug>] [--excerpt <text>] [--update <ID>]
#   status は省略時 draft。--slug は URL スラッグ（英単語2〜3語推奨）、
#   --excerpt は抜粋＝meta description の元テキスト。認証情報はカレントディレクトリ（作業フォルダ）の .env から読む。
#   同じスラッグの投稿が既にある場合は重複入稿を防ぐため中断する。上書きするときは --update <ID> を付ける。
#   --eyecatch <画像> を付けると「<スラッグ>-eyecatch.<拡張子>」の英語ファイル名でアップロードし、
#   アイキャッチ（featured_media）として設定する。alt はタイトルが入る。
#   --category <名前|ID> でカテゴリを設定する（カンマ区切りで複数可）。名前は media/categories.json の
#   台帳で ID に解決する（台帳が無ければ初回に自動生成）。
#
# 単独モード（タイトル・本文ファイル不要）:
#   --pull <ID>          … WP上の現在の本文を取得して articles/<slug>/post.html に保存する。
#                          公開後の修正は必ずこれで取得した最新版を編集し、--update で書き戻す
#                          （ローカルの古い原稿からの --update 直行は、WP側の手直しを消すので禁止）。
#   --sync-categories    … WPのカテゴリ一覧を取得して media/categories.json（台帳）を上書きする。
#                          カテゴリを増やした・変えたときに実行する。
set -euo pipefail

SLUG="" EXCERPT="" UPDATE_ID="" EYECATCH="" CATEGORY="" PULL_ID="" SYNC_CATS=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --excerpt) EXCERPT="$2"; shift 2 ;;
    --update) UPDATE_ID="$2"; shift 2 ;;
    --eyecatch) EYECATCH="$2"; shift 2 ;;
    --category) CATEGORY="$2"; shift 2 ;;
    --pull) PULL_ID="$2"; shift 2 ;;
    --sync-categories) SYNC_CATS=1; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

if [ -z "$PULL_ID" ] && [ -z "$SYNC_CATS" ] && [ $# -lt 2 ]; then
  echo "使い方: $0 <タイトル> <本文HTMLファイル> [status] [--slug <slug>] [--excerpt <text>] [--category <名前|ID>]" >&2
  echo "        $0 --pull <ID> | --sync-categories" >&2
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

# ---- 単独モード: --pull / --sync-categories ----
if [ -n "$PULL_ID" ] || [ -n "$SYNC_CATS" ]; then
  PULL_ID="$PULL_ID" SYNC_CATS="$SYNC_CATS" python3 - <<'PY'
import base64, json, os, sys, urllib.error, urllib.request
from pathlib import Path

url = os.environ["WP_URL"].rstrip("/")
user = os.environ["WP_USER"]
password = os.environ["WP_APP_PASSWORD"]
token = base64.b64encode(f"{user}:{password}".encode()).decode()

def api(path, data=None, method="GET"):
    req = urllib.request.Request(f"{url}/wp-json/wp/v2{path}",
                                 data=json.dumps(data).encode() if data else None, method=method)
    req.add_header("Authorization", f"Basic {token}")
    if data:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as res:
        return json.load(res)

pull_id = os.environ.get("PULL_ID", "")
if pull_id:
    try:
        post = api(f"/posts/{pull_id}?context=edit")
    except urllib.error.HTTPError as e:
        print(f"取得失敗: HTTP {e.code}（ID {pull_id} の記事が存在するか確認してください）", file=sys.stderr)
        sys.exit(1)
    slug = post.get("slug") or f"post-{pull_id}"
    raw = post["content"]["raw"]
    dest_dir = Path("articles") / slug
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / "post.html"
    if dest.exists():
        dest.replace(dest_dir / "post.html.bak")  # 直前のローカル版は1世代だけ残す
    dest.write_text(raw, encoding="utf-8")
    title = post["title"].get("raw") or post["title"].get("rendered", "")
    print(f"WPの現在の本文を取得しました（ID: {pull_id} / status: {post['status']} / タイトル: {title}）")
    print(f"保存先: {dest}")
    print(f"このファイルを編集し、書き戻すときは: wp-post.sh \"{title}\" {dest} {post['status']} --update {pull_id}")

if os.environ.get("SYNC_CATS", ""):
    cats, page = [], 1
    while True:
        try:
            batch = api(f"/categories?per_page=100&page={page}")
        except urllib.error.HTTPError as e:
            print(f"カテゴリ取得失敗: HTTP {e.code}", file=sys.stderr)
            sys.exit(1)
        cats += batch
        if len(batch) < 100:
            break
        page += 1
    ledger = [{"id": c["id"], "name": c["name"], "slug": c["slug"],
               "description": c.get("description", ""), "count": c.get("count", 0)} for c in cats]
    Path("media").mkdir(exist_ok=True)
    Path("media/categories.json").write_text(
        json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"カテゴリ台帳を更新しました: media/categories.json（{len(ledger)}件）")
    for c in ledger:
        print(f"  {c['id']:>4}  {c['name']}（slug: {c['slug']} / 記事数: {c['count']}）")
PY
  exit 0
fi

if [ -n "$EYECATCH" ] && [ ! -f "$EYECATCH" ]; then
  echo "アイキャッチ画像が見つかりません: $EYECATCH" >&2
  exit 1
fi

TITLE="$1" FILE="$2" STATUS="${3:-draft}" SLUG="$SLUG" EXCERPT="$EXCERPT" UPDATE_ID="$UPDATE_ID" EYECATCH="$EYECATCH" CATEGORY="$CATEGORY" python3 - <<'PY'
import base64, json, os, sys, urllib.error, urllib.parse, urllib.request
from pathlib import Path

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

# カテゴリ: 名前は media/categories.json（台帳）で ID に解決する。WPへの問い合わせは
# 台帳が無い初回の自動生成時だけ（以降は --sync-categories を実行したときのみ更新）
category = os.environ.get("CATEGORY", "")
if category:
    ledger_path = Path("media/categories.json")
    if not ledger_path.exists():
        cats, page = [], 1
        while True:
            batch = api(f"/categories?per_page=100&page={page}")
            cats += batch
            if len(batch) < 100:
                break
            page += 1
        ledger_path.parent.mkdir(exist_ok=True)
        ledger_path.write_text(json.dumps(
            [{"id": c["id"], "name": c["name"], "slug": c["slug"],
              "description": c.get("description", ""), "count": c.get("count", 0)} for c in cats],
            ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"カテゴリ台帳が無かったのでWPから自動生成しました: {ledger_path}")
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    ids = []
    for tok in [t.strip() for t in category.split(",") if t.strip()]:
        if tok.isdigit():
            ids.append(int(tok))
            continue
        hit = next((c for c in ledger if c["name"] == tok or c["slug"] == tok), None)
        if not hit:
            names = "、".join(c["name"] for c in ledger)
            print(f"カテゴリ「{tok}」が台帳にありません（台帳: {names}）。", file=sys.stderr)
            print("WP側でカテゴリを追加・変更した場合は --sync-categories で台帳を更新してください。", file=sys.stderr)
            sys.exit(1)
        ids.append(hit["id"])
    payload["categories"] = ids

try:
    if update_id:
        post = api(f"/posts/{update_id}", payload, "POST")
    else:
        post = api("/posts", payload, "POST")
except urllib.error.HTTPError as e:
    print(f"入稿失敗: HTTP {e.code}", file=sys.stderr)
    print(e.read().decode(errors="replace"), file=sys.stderr)
    if category:
        print("カテゴリ指定が原因の場合、台帳が古い可能性があります。--sync-categories で更新して再実行してください。", file=sys.stderr)
    sys.exit(1)

post_id = post["id"]
action = "更新" if update_id else "入稿"
print(f"{action}しました（status: {status} / ID: {post_id} / slug: {post.get('slug', '')}）")

# アイキャッチ: スラッグ由来の英語ファイル名でアップロードして featured_media に設定
eyecatch = os.environ.get("EYECATCH", "")
if eyecatch:
    src = Path(eyecatch)
    final_slug = post.get("slug") or slug or "post"
    filename = f"{final_slug}-eyecatch{src.suffix.lower()}"
    mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
            "webp": "image/webp", "gif": "image/gif"}.get(src.suffix.lower().lstrip("."))
    if not mime:
        print(f"アイキャッチ未対応の形式です: {src.suffix}（PNG/JPEG/WebP/GIF を使う）", file=sys.stderr)
        sys.exit(1)
    req = urllib.request.Request(f"{url}/wp-json/wp/v2/media", data=src.read_bytes(), method="POST")
    req.add_header("Content-Type", mime)
    req.add_header("Content-Disposition", f'attachment; filename="{filename}"')
    req.add_header("Authorization", f"Basic {token}")
    try:
        with urllib.request.urlopen(req) as res:
            media = json.load(res)
        api(f"/media/{media['id']}", {"alt_text": title}, "POST")
        api(f"/posts/{post_id}", {"featured_media": media["id"]}, "POST")
        print(f"アイキャッチを設定しました（メディアID: {media['id']} / {media['source_url']}）")
    except urllib.error.HTTPError as e:
        print(f"アイキャッチ設定に失敗: HTTP {e.code}（記事の{action}自体は完了しています）", file=sys.stderr)
        print(e.read().decode(errors="replace"), file=sys.stderr)
        sys.exit(1)

print(f"編集ページ: {url}/wp-admin/post.php?post={post_id}&action=edit")
PY
