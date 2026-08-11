#!/usr/bin/env python3
"""draft.md → Gutenberg ブロック（post.html）決定論変換

使い方（作業フォルダから）:
  <seo-grit>/scripts/md2gutenberg.py articles/<slug>/draft.md
  → articles/<slug>/post.html に出力

ブロックのHTMLはテンプレートファイル（JSON）から読む:
  1. --blocks で指定されたファイル
  2. カレントディレクトリの media/blocks.json（サイト別デザイン）
  3. seo-grit 同梱の templates/blocks-standard.json（標準デザイン）

対応マーカー（【】と [] のどちらでも可）:
  【目次】                          … H2から自動生成（マーカーが無ければリード直後に自動挿入）
  【吹き出し】「テキスト」 / 【吹き出し：テキスト】
  【ポイント行（黄・結論）】1文目。補足文。   … 色は 黄/紫/緑/赤
  【注意ボックス（赤）：ヘッダー文】本文
  【まとめボックス（水色）：ヘッダー文】      … 直後のリスト行を中に取り込む
  【比較表：タイトル】                       … 直後のMarkdown表を装飾表に（マーカー無しの表も同様）
  【画像：URL｜alt テキスト】                … 先に wp-media.sh でアップロードしたURLを使う
  【CTA】ラベル：… / 見出し：… / 本文：… / ボタン：ラベル｜URL  … 複数行ブロック
  出典行：テキスト                           … 表の直下の出典表記
"""
import argparse
import json
import re
import sys
from pathlib import Path

MARK_RE = re.compile(r"^[【\[](.+?)[】\]]\s*(.*)$")
TABLE_ROW_RE = re.compile(r"^\|(.+)\|\s*$")
TABLE_SEP_RE = re.compile(r"^\|[\s:\-|]+\|\s*$")
OL_RE = re.compile(r"^\d+\.\s+(.*)$")
UL_RE = re.compile(r"^-\s+(.*)$")
LEFT_ALIGN_HEADERS = {"備考", "内容", "説明", "詳細"}


def inline(text):
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text.strip())
    return re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', text)


def wp(name, html, attrs=""):
    return f"<!-- wp:{name}{attrs} -->\n{html}\n<!-- /wp:{name} -->"


def paragraph(text):
    return wp("paragraph", f"<p>{inline(text)}</p>")


def split_point(text):
    """ポイント行を「太字の1文目」と「補足」に分ける"""
    text = inline(text)
    m = re.match(r"(.+?)。\s*(.*)$", text)
    if m and m.group(2):
        return m.group(1), m.group(2)
    return text.rstrip("。"), ""


class Converter:
    def __init__(self, blocks):
        self.b = blocks

    # ---------- 部品 ----------
    def balloon(self, text):
        text = text.strip()
        if not text.startswith("「"):
            text = f"「{text}」"
        return wp("html", self.b["balloon"].format(text=text))

    def point(self, color, text):
        key = {"黄": "point_yellow", "紫": "point_purple", "緑": "point_green", "赤": "point_red"}.get(color)
        if not key:
            raise SystemExit(f"未対応のポイント行の色: {color}")
        head, sub = split_point(text)
        return wp("html", self.b[key].format(head=head, sub=sub))

    def box(self, kind, header, body_html):
        key = {"赤": "box_red", "水色": "box_blue", "黄": "box_yellow"}.get(kind, "box_blue")
        return wp("html", self.b[key].format(header=header, body=body_html))

    def toc(self, sections):
        items = "\n".join(
            self.b["toc_item"].format(n=i + 1, anchor=a, text=t) for i, (a, t) in enumerate(sections)
        )
        return wp("html", self.b["toc"].format(items=items))

    def cta(self, fields):
        return wp("html", self.b["cta"].format(
            label=fields.get("ラベル", "おしらせ"),
            heading=fields.get("見出し", ""),
            body="<br>".join(fields.get("本文", [])),
            button_label=fields.get("ボタンラベル", ""),
            button_url=fields.get("ボタンURL", "#"),
        ))

    def image(self, url, alt):
        return wp("html", self.b["image"].format(url=url, alt=alt))

    def source_line(self, text):
        return wp("html", self.b["source_line"].format(text=inline(text)))

    def table(self, rows):
        header, body = rows[0], rows[1:]
        aligns = ["left"] + [
            "left" if h.strip() in LEFT_ALIGN_HEADERS else "center" for h in header[1:]
        ]
        ths = "".join(
            self.b["table_th"].format(text=h.strip(), align=a) for h, a in zip(header, aligns)
        )
        trs = []
        for i, row in enumerate(body):
            tds = []
            for j, cell in enumerate(row):
                cell = cell.strip()
                if re.match(r"^[◯○]\s?", cell):
                    cell = self.b["badge_ok"].format(text=cell)
                elif re.match(r"^[×✕]\s?", cell):
                    cell = self.b["badge_ng"].format(text=cell)
                else:
                    cell = inline(cell)
                tds.append(self.b["table_td"].format(text=cell, align=aligns[j], bold="bold" if j == 0 else "normal"))
            trs.append(self.b["table_tr"].format(cells="".join(tds), bg=self.b["row_bg"][i % 2]))
        return wp("html", self.b["table"].format(thead=ths, tbody="\n".join(trs)))

    def list_block(self, items, ordered):
        li = "".join(f"<li>{inline(x)}</li>" for x in items)
        tag = "ol" if ordered else "ul"
        attrs = ' {"ordered":true}' if ordered else ""
        return wp("list", f"<{tag}>{li}</{tag}>", attrs)


def read_lines(path):
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    if lines and lines[0].strip() == "---":  # frontmatter を飛ばす
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                return lines[i + 1:]
    return lines


def collect_table(lines, i):
    rows = []
    while i < len(lines) and TABLE_ROW_RE.match(lines[i].strip()):
        if not TABLE_SEP_RE.match(lines[i].strip()):
            rows.append([c for c in lines[i].strip().strip("|").split("|")])
        i += 1
    return rows, i


def collect_list(lines, i, regex):
    items = []
    while i < len(lines):
        m = regex.match(lines[i].strip())
        if not m:
            break
        items.append(m.group(1))
        i += 1
    return items, i


def convert(path, blocks_path):
    conv = Converter(json.loads(Path(blocks_path).read_text(encoding="utf-8")))
    lines = read_lines(path)

    # 先に H2 一覧を作る（目次・アンカー用）。「リード」は除外
    sections = []
    for ln in lines:
        m = re.match(r"^##\s+(.+)$", ln)
        if m and m.group(1).strip() != "リード":
            sections.append((f"sec{len(sections) + 1}", m.group(1).strip()))

    out, i, h2_count = [], 0, 0
    in_lead, toc_done = False, False

    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        i += 1
        if not line or line == "---":
            continue
        if line.startswith("# ") and not line.startswith("## "):
            continue  # H1 はタイトルとして別送するので出力しない

        m = re.match(r"^##\s+(.+)$", line)
        if m:
            title = m.group(1).strip()
            if title == "リード":
                in_lead = True
                continue
            if in_lead and not toc_done:  # リード終了位置に目次を自動挿入
                out.append(conv.toc(sections))
                toc_done = True
            in_lead = False
            h2_count += 1
            out.append(wp("heading", f'<h2 class="wp-block-heading" id="sec{h2_count}">{inline(title)}</h2>'))
            continue
        m = re.match(r"^###\s+(.+)$", line)
        if m:
            out.append(wp("heading", f'<h3 class="wp-block-heading">{inline(m.group(1))}</h3>', ' {"level":3}'))
            continue

        mark = MARK_RE.match(line)
        if mark and re.match(r"^\[[^\]]+\]\(", line):
            mark = None  # 行頭のMarkdownリンクはマーカーではなく本文
        if mark:
            name, rest = mark.group(1), mark.group(2).strip()
            if name == "目次":
                out.append(conv.toc(sections))
                toc_done = True
                continue
            if name.startswith("吹き出し"):
                # 【吹き出し】「…」は本文優先、【吹き出し：…】はコロン後を使う
                text = rest if rest else (name.split("：", 1)[1] if "：" in name else "")
                out.append(conv.balloon(text))
                continue
            m2 = re.match(r"^ポイント行（(.)・[^）]*）(?:：(.*))?$", name)
            if m2:
                out.append(conv.point(m2.group(1), (m2.group(2) or rest).strip()))
                continue
            m2 = re.match(r"^(注意ボックス|まとめボックス|結論ボックス)（(.+?)）(?:[：／](.*))?$", name)
            if m2:
                kind, color, header = m2.group(1), m2.group(2), (m2.group(3) or "").strip()
                default = {"注意ボックス": "注意してください", "まとめボックス": "この章のまとめ",
                           "結論ボックス": "この章の結論"}[kind]
                if not rest and kind != "まとめボックス":
                    # 本文なし＝ヘッダーに書いた1文を本文扱いにする
                    rest, header = header, default
                if kind == "まとめボックス":
                    # 直後のリスト行を取り込む
                    while i < len(lines) and not lines[i].strip():
                        i += 1
                    ordered = bool(OL_RE.match(lines[i].strip())) if i < len(lines) else False
                    items, i = collect_list(lines, i, OL_RE if ordered else UL_RE)
                    tag = "ol" if ordered else "ul"
                    li = "".join(f"<li>{inline(x)}</li>" for x in items)
                    body = conv.b["box_list"].format(tag=tag, items=li)
                    out.append(conv.box(color, header or default, body))
                else:
                    out.append(conv.box(color, header or default, f"{inline(rest)}"))
                continue
            if name.startswith("比較表"):
                while i < len(lines) and not lines[i].strip():
                    i += 1
                rows, i = collect_table(lines, i)
                if not rows:
                    raise SystemExit(
                        f"【{name}】の直後にMarkdown表がありません。"
                        "マーカーの次の行に | 列 | 列 | 形式で表データを書いてください"
                        "（データを持たない旧形式のdraftはこのスクリプトでは変換できません）"
                    )
                out.append(conv.table(rows))
                continue
            if name.startswith("画像"):
                body = name.split("：", 1)[1] if "：" in name else rest
                url, _, alt = body.partition("｜")
                out.append(conv.image(url.strip(), alt.strip()))
                continue
            if name == "CTA":
                fields = {"本文": []}
                while i < len(lines) and lines[i].strip():
                    ln = lines[i].strip()
                    i += 1
                    key, _, val = ln.partition("：")
                    if key == "ボタン":
                        lab, _, url = val.partition("｜")
                        fields["ボタンラベル"], fields["ボタンURL"] = lab.strip(), url.strip()
                    elif key == "本文":
                        fields["本文"].append(inline(val))
                    else:
                        fields[key] = val.strip()
                out.append(conv.cta(fields))
                continue
            raise SystemExit(f"未対応のマーカーです: {line}")

        if line.startswith("出典行："):
            out.append(conv.source_line(line.split("：", 1)[1]))
            continue
        if TABLE_ROW_RE.match(line):
            rows, i = collect_table(lines, i - 1)
            out.append(conv.table(rows))
            continue
        if OL_RE.match(line):
            items, i = collect_list(lines, i - 1, OL_RE)
            out.append(conv.list_block(items, ordered=True))
            continue
        if UL_RE.match(line):
            items, i = collect_list(lines, i - 1, UL_RE)
            out.append(conv.list_block(items, ordered=False))
            continue
        out.append(paragraph(line))

    return "\n\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description="draft.md → Gutenberg post.html")
    ap.add_argument("draft")
    ap.add_argument("-o", "--output", help="省略時は draft と同じフォルダの post.html")
    ap.add_argument("--blocks", help="ブロックテンプレJSON（省略時: ./media/blocks.json → 標準）")
    args = ap.parse_args()

    blocks = args.blocks
    if not blocks:
        site = Path("media/blocks.json")
        std = Path(__file__).resolve().parent.parent / "templates" / "blocks-standard.json"
        blocks = site if site.exists() else std
    html = convert(args.draft, blocks)

    # 検証: ブロックコメントの開閉一致・マーカー残留なし
    from collections import Counter
    opens = Counter(re.findall(r"<!-- wp:(\w+)", html))
    closes = Counter(re.findall(r"<!-- /wp:(\w+)", html))
    if opens != closes:
        raise SystemExit(f"ブロック開閉が不一致: {opens - closes} / {closes - opens}")
    leftover = [l for l in html.splitlines() if re.search(r"[【\[](吹き出し|ポイント行|注意ボックス|まとめボックス|比較表|目次|CTA|画像)", l) and "<!--" not in l]
    if leftover:
        raise SystemExit("未変換のマーカーが残っています:\n" + "\n".join(leftover[:5]))

    out_path = Path(args.output) if args.output else Path(args.draft).parent / "post.html"
    out_path.write_text(html, encoding="utf-8")
    n_blocks = sum(opens.values())
    print(f"変換しました: {out_path}（{n_blocks}ブロック / テンプレ: {blocks}）")


if __name__ == "__main__":
    main()
