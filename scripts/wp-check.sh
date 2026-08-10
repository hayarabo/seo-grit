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
import base64, functools, json, os, sys, urllib.error, urllib.request

print = functools.partial(print, flush=True)

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

# 2. 認証（失敗時は「記入ミス」か「サーバーがヘッダーを渡していない」かを自動切り分け）
def try_auth(tok):
    """認証を試み、(エラーコード, レスポンス) を返す。成功時はエラーコード None。"""
    req = urllib.request.Request(f"{url}/wp-json/wp/v2/users/me")
    req.add_header("Authorization", f"Basic {tok}")
    try:
        with urllib.request.urlopen(req) as res:
            return None, json.load(res)
    except urllib.error.HTTPError as e:
        try:
            code = json.load(e).get("code", f"http_{e.code}")
        except Exception:
            code = f"http_{e.code}"
        return code, None

auth_code, me = try_auth(token)
if me is None:
    err = ["NG: 認証失敗。原因を診断します…", ""]
    # 診断1（ローカル）: アプリケーションパスワードの形式チェック（英数24文字、スペースは無視）
    compact = password.replace(" ", "")
    format_ok = len(compact) == 24 and compact.isalnum()
    # 診断2: でたらめな認証情報と同じエラーになるか比べる（コードを出し分けるサーバーなら確定できる）
    bogus = base64.b64encode(b"grit_diagnostic_user:abcd efgh ijkl mnop qrst uvwx").decode()
    bogus_code, _ = try_auth(bogus)

    if not format_ok:
        err += [
            f"原因: WP_APP_PASSWORD の形式が正しくありません（現在: スペースを除いて{len(compact)}文字）。",
            "アプリケーションパスワードは「英数4文字×6ブロック（スペース区切り、計24文字）」です。",
            "コピペで欠けた・余計な文字が入った可能性が高いので、WP管理画面で再発行して貼り直してください。",
        ]
    elif auth_code in ("incorrect_password", "invalid_username") or auth_code != bogus_code:
        which = "WP_USER（ユーザー名）" if auth_code == "invalid_username" else "WP_USER / WP_APP_PASSWORD"
        err += [
            f"原因: {which} が間違っています（サーバーには届いています。記入内容の問題です）。",
            "アプリケーションパスワードはスペース込みでそのまま貼り付けます。",
        ]
    else:
        err += [
            "原因: 認証情報の形式は正しいのに未ログイン扱いです。このサーバーが Authorization ヘッダーを",
            "      PHP に渡していない可能性が高いです（Xserver など国内の共用レンタルサーバーでよくある挙動）。",
            "対処: WordPress がインストールされているフォルダの .htaccess に次の1行を追記してください:",
            "",
            '  SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1',
            "",
            "追記後、この接続テストをもう一度実行してください。",
            "（すでに追記済みで失敗する場合は、アプリケーションパスワードを再発行して貼り直してください）",
        ]
    print("\n".join(err), file=sys.stderr)
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
posts = []
try:
    posts = get("/wp/v2/posts?per_page=5&status=publish", auth=True)
    print(f"OK: 公開記事 {len(posts)} 件を取得（レギュレーションの学習素材になります）")
    for p in posts:
        print(f"  - {p.get('title', {}).get('rendered', '(無題)')}")
except Exception:
    print("注意: 記事一覧を取得できませんでした")

# 5. OGP・meta description の出力チェック（SNSシェアでカード画像が出るか）
if posts:
    try:
        req = urllib.request.Request(posts[0]["link"], headers={"User-Agent": "Mozilla/5.0 (grit-check)"})
        with urllib.request.urlopen(req) as res:
            html = res.read(300_000).decode("utf-8", errors="replace")
        head = html.split("</head>", 1)[0].lower()
        has_ogimage = 'property="og:image"' in head or "property='og:image'" in head
        has_desc = 'name="description"' in head or "name='description'" in head
        if has_ogimage and has_desc:
            print("OK: OGP・meta description が出力されています（SNSシェアでカード表示されます）")
        else:
            missing = []
            if not has_ogimage:
                missing.append("OGPタグ（og:image 等）")
            if not has_desc:
                missing.append("meta description")
            print(f"注意: {'と'.join(missing)} が出力されていません。")
            print("  このままだと X 等でシェアしてもアイキャッチ画像付きのカードが表示されず、")
            print("  検索結果の説明文もコントロールできません。")
            print("  対処: SEOプラグイン（例: SEO SIMPLE PACK）の導入、またはテーマでの出力対応を推奨します。")
    except Exception:
        print("注意: OGPチェックをスキップしました（記事ページを取得できず）")

print("接続テスト完了 🎉 入稿できる状態です。")
PY
