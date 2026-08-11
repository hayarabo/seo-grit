#!/usr/bin/env bash
# WordPress メディアライブラリへ画像をアップロードし、URL と ID を表示する
# 使い方（作業フォルダから）:
#   <seo-grit>/scripts/wp-media.sh <画像ファイル> [--alt "代替テキスト"] [--title "タイトル"]
# 認証情報はカレントディレクトリの .env から読む。
# 出力の URL を draft.md の 【画像：URL｜alt】 マーカーに貼って使う。
set -euo pipefail

ALT="" TITLE=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --alt) ALT="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

if [ $# -lt 1 ]; then
  echo "使い方: $0 <画像ファイル> [--alt <text>] [--title <text>]" >&2
  exit 1
fi
if [ ! -f .env ]; then
  echo "カレントディレクトリに .env がありません。作業フォルダで実行してください。" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
source .env
set +a

FILE="$1" ALT="$ALT" TITLE="$TITLE" python3 - <<'PY'
import base64, json, mimetypes, os, sys, urllib.error, urllib.request
from pathlib import Path

file = Path(os.environ["FILE"])
alt = os.environ.get("ALT", "")
title = os.environ.get("TITLE", "")
url = os.environ["WP_URL"].rstrip("/")
token = base64.b64encode(f"{os.environ['WP_USER']}:{os.environ['WP_APP_PASSWORD']}".encode()).decode()

mime = mimetypes.guess_type(file.name)[0]
if not mime or not mime.startswith("image/"):
    print(f"画像ファイルではありません: {file.name}（WP は SVG を既定で受け付けないため PNG/JPEG/WebP を使う）", file=sys.stderr)
    sys.exit(1)

req = urllib.request.Request(f"{url}/wp-json/wp/v2/media", data=file.read_bytes(), method="POST")
req.add_header("Content-Type", mime)
req.add_header("Content-Disposition", f'attachment; filename="{file.name}"')
req.add_header("Authorization", f"Basic {token}")
try:
    with urllib.request.urlopen(req) as res:
        media = json.load(res)
except urllib.error.HTTPError as e:
    print(f"アップロード失敗: HTTP {e.code}", file=sys.stderr)
    print(e.read().decode(errors="replace"), file=sys.stderr)
    sys.exit(1)

media_id = media["id"]
if alt or title:
    patch = {}
    if alt:
        patch["alt_text"] = alt
    if title:
        patch["title"] = title
    req = urllib.request.Request(f"{url}/wp-json/wp/v2/media/{media_id}",
                                 data=json.dumps(patch).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Basic {token}")
    urllib.request.urlopen(req).read()

print(f"アップロードしました（ID: {media_id}）")
print(f"URL: {media['source_url']}")
PY
