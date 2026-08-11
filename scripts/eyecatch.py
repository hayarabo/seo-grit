#!/usr/bin/env python3
"""アイキャッチ画像の自動生成（タイトル文字入れ）

使い方（作業フォルダから）:
  python3 <seo-grit>/scripts/eyecatch.py "記事タイトル" [-o eyecatch.png]

背景の解決順（デフォルトで動き、後から差し替えられる）:
  1. --bg で指定した画像
  2. 作業フォルダの media/eyecatch-bg.png または media/eyecatch-bg.svg（サイト別の共有背景）
  3. seo-grit 同梱のデフォルト背景（templates/eyecatch-bg.svg）
     初回使用時に media/eyecatch-bg.svg へ複製するので、以降は
     「背景を変えたい」という指示でこのファイルを編集すれば全記事に反映される

タイトルは「｜」で行を分け、長い行は自動で折り返し・フォントサイズ調整する。
--post <ID> を付けると WordPress にアップロードして、その記事のアイキャッチに設定する
（カレントディレクトリの .env を使う）。

必要コマンド: rsvg-convert（brew install librsvg）。無ければ ImageMagick (magick) を試す。
"""
import argparse
import base64
import json
import math
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

W, H = 1200, 630
FONT = "Hiragino Kaku Gothic ProN, Hiragino Sans, sans-serif"


def vis_len(s):
    """視覚幅（全角=1、半角=0.55）"""
    return sum(0.55 if ord(c) < 0x3000 and c not in "→←" else 1.0 for c in s)


def _tokens(seg):
    """英単語・数字・カタカナ語は1トークン（途中で改行しない）"""
    return re.findall(r"[0-9A-Za-z.,!?%&+\-]+ ?|[ァ-ヶー]+|.", seg)


def _split_balanced(seg, max_vis):
    """視覚幅が収まるまで、中央に最も近いトークン境界で二分割する"""
    if vis_len(seg) <= max_vis:
        return [seg]
    tokens = _tokens(seg)
    if len(tokens) < 2:
        return [seg]
    PARTICLES = set("はがをにでとのもへや")
    total, cum, best = vis_len(seg), 0.0, None
    for i in range(len(tokens) - 1):
        cum += vis_len(tokens[i])
        d = abs(cum - total / 2)
        nxt = tokens[i + 1]
        if nxt[0] in PARTICLES or nxt[0] in "ーっゃゅょん、。・）」』":
            d += 2.5  # 助詞・小書き文字の前では折り返さない
        if best is None or d < best[0]:
            best = (d, i)
    left = "".join(tokens[:best[1] + 1]).strip()
    right = "".join(tokens[best[1] + 1:]).strip()
    if not left or not right:
        return [seg]
    return _split_balanced(left, max_vis) + _split_balanced(right, max_vis)


def wrap_title(title, max_vis=16.0):
    """「｜」で区切り、長い行は自然な境界で折り返す"""
    lines = []
    for seg in re.split(r"[｜|]", title):
        seg = seg.strip()
        if seg:
            lines.extend(_split_balanced(seg, max_vis))
    return lines or [title]


def default_bg_svg():
    """内蔵の標準背景（seo-grit 標準デザインのトーン）"""
    dots = []
    for gx in range(6):
        for gy in range(4):
            dots.append(f'<circle cx="{60 + gx * 36}" cy="{60 + gy * 36}" r="5" fill="#c5d7e4"/>')
            dots.append(f'<circle cx="{W - 60 - gx * 36}" cy="{H - 60 - gy * 36}" r="5" fill="#c5d7e4"/>')
    return (
        f'<rect width="{W}" height="{H}" fill="#eef4f8"/>'
        f'<rect x="0" y="0" width="{W}" height="18" fill="#2f6690"/>'
        f'<rect x="0" y="{H - 18}" width="{W}" height="18" fill="#2f6690"/>'
        + "".join(dots)
    )


def build_svg(title, bg_path, text_color, halo_color, font):
    lines = wrap_title(title)
    longest = max(vis_len(l) for l in lines)
    fs = max(40, min(76, int((W - 140) / longest)))
    lh = int(fs * 1.45)
    total = lh * len(lines)
    y0 = (H - total) // 2 + int(fs * 0.9)

    if bg_path:
        data = base64.b64encode(Path(bg_path).read_bytes()).decode()
        mime = mimetypes.guess_type(str(bg_path))[0] or "image/png"
        bg = (f'<image href="data:{mime};base64,{data}" x="0" y="0" width="{W}" height="{H}" '
              f'preserveAspectRatio="xMidYMid slice"/>')
    else:
        bg = default_bg_svg()

    texts = "".join(
        f'<text x="{W // 2}" y="{y0 + i * lh}" text-anchor="middle" '
        f'font-family="{font}" font-size="{fs}" font-weight="bold" fill="{text_color}" '
        f'stroke="{halo_color}" stroke-width="{int(fs * 0.22)}" stroke-linejoin="round" '
        f'paint-order="stroke">{line}</text>'
        for i, line in enumerate(lines)
    )
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}">{bg}{texts}</svg>')


def render_png(svg, out_path):
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False, encoding="utf-8") as f:
        f.write(svg)
        tmp = f.name
    try:
        if shutil.which("rsvg-convert"):
            subprocess.run(["rsvg-convert", "-w", str(W * 2), tmp, "-o", str(out_path)], check=True)
        elif shutil.which("magick"):
            subprocess.run(["magick", "-density", "144", tmp, str(out_path)], check=True)
        else:
            raise SystemExit("rsvg-convert も magick もありません。`brew install librsvg` を実行してください")
    finally:
        os.unlink(tmp)


def wp_set_featured(png_path, post_id, alt):
    if not Path(".env").exists():
        raise SystemExit("--post を使うにはカレントディレクトリに .env が必要です")
    env = {}
    for ln in Path(".env").read_text(encoding="utf-8").splitlines():
        m = re.match(r'^\s*([A-Z_]+)\s*=\s*"?([^"#]*)"?\s*$', ln)
        if m:
            env[m.group(1)] = m.group(2).strip()
    url = env["WP_URL"].rstrip("/")
    token = base64.b64encode(f"{env['WP_USER']}:{env['WP_APP_PASSWORD']}".encode()).decode()

    def api(path, data=None, ctype=None, extra=None, method=None):
        req = urllib.request.Request(f"{url}/wp-json/wp/v2{path}", data=data,
                                     method=method or ("POST" if data else "GET"))
        if ctype:
            req.add_header("Content-Type", ctype)
        req.add_header("Authorization", f"Basic {token}")
        for k, v in (extra or {}).items():
            req.add_header(k, v)
        with urllib.request.urlopen(req) as res:
            return json.load(res)

    # SNS/SEO 用にスラッグ由来の英語ファイル名でアップロードする
    post_slug = api(f"/posts/{post_id}?context=edit").get("slug") or "post"
    filename = f"{post_slug}-eyecatch{Path(png_path).suffix.lower()}"
    media = api("/media", Path(png_path).read_bytes(), "image/png",
                {"Content-Disposition": f'attachment; filename="{filename}"'})
    if alt:
        api(f"/media/{media['id']}", json.dumps({"alt_text": alt}).encode(), "application/json")
    api(f"/posts/{post_id}", json.dumps({"featured_media": media["id"]}).encode(), "application/json")
    print(f"アイキャッチを設定しました（記事ID: {post_id} / メディアID: {media['id']}）")
    print(f"URL: {media['source_url']}")


def main():
    ap = argparse.ArgumentParser(description="アイキャッチ自動生成")
    ap.add_argument("title")
    ap.add_argument("-o", "--output", default="eyecatch.png")
    ap.add_argument("--bg", help="背景画像（省略時: media/eyecatch-bg.png → 内蔵標準背景）")
    ap.add_argument("--color", default="#23282d", help="文字色")
    ap.add_argument("--halo", default="#ffffff", help="縁取り色")
    ap.add_argument("--font", default=FONT)
    ap.add_argument("--post", type=int, help="WordPress 記事IDにアイキャッチとして設定")
    ap.add_argument("--alt", default="", help="画像のaltテキスト（省略時はタイトル）")
    args = ap.parse_args()

    bg = args.bg
    if bg and not Path(bg).exists():
        raise SystemExit(f"背景画像が見つかりません: {bg}")
    if not bg:
        for cand in ("media/eyecatch-bg.png", "media/eyecatch-bg.svg"):
            if Path(cand).exists():
                bg = cand
                break
    if not bg:
        default_svg = Path(__file__).resolve().parent.parent / "templates" / "eyecatch-bg.svg"
        if default_svg.exists():
            # 同梱デフォルトを作業フォルダへ複製して使う（以降はユーザーが編集できる）
            local = Path("media/eyecatch-bg.svg")
            if Path("media").is_dir() and not local.exists():
                local.write_text(default_svg.read_text(encoding="utf-8"), encoding="utf-8")
                print(f"デフォルト背景を {local} に複製しました（編集すれば全記事に反映されます）")
                bg = str(local)
            else:
                bg = str(default_svg)

    svg = build_svg(args.title, bg, args.color, args.halo, args.font)
    render_png(svg, args.output)
    src = bg if bg else "内蔵の標準背景"
    print(f"生成しました: {args.output}（背景: {src}）")

    if args.post:
        wp_set_featured(args.output, args.post, args.alt or args.title)


if __name__ == "__main__":
    main()
