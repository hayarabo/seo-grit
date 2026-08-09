# seo-grit 標準デザイン部品集

どの WordPress テーマでも崩れない「見やすいデザイン部品」の Gutenberg マークアップ集。
テーマ固有ブロック（吹き出し等）が使えない・特定できない場合の補完として `/grit-write` が使う。

## デザインの原則

- アクセントカラーはデフォルト **#2f6690**（スチールブルー）。ユーザーのサイトに合わせて regulation.md で上書きしてよい
- 意味色は3系統: 注意=赤（#b3261e / 背景 #fdecea）、チェック=緑（#2e7d4f / 背景 #e9f4ee）、整理・メモ=紫（#6246b5 / 背景 #f0edfa）。意味と色は記事全体で固定する
- **絵文字を使わない。** デバイス（Mac/iOS/Android/Windows）で見た目が変わるため、アイコンはすべてインラインSVGで埋め込む
- **色だけで意味を伝えない**（可否は ◯× を併記、注意は三角アイコンを付ける — 色覚多様性への配慮）
- インラインスタイルのみで完結させる（テーマのCSSに依存しない = どのテーマでも崩れない）

## 1. 目次ボックス（折りたたみ付き・JS不要）

`<details open>` により初期状態は展開。読者はワンタップで折りたためる。

```html
<!-- wp:html -->
<details open style="border:1px solid #ddd;border-radius:10px;margin:1.5em 0;background:#fafafa;">
  <summary style="cursor:pointer;padding:14px 18px;font-weight:bold;list-style:none;"><svg width="16" height="16" viewBox="0 0 24 24" fill="#2f6690" style="vertical-align:-2px;margin-right:8px;"><path d="M4 6h2v2H4V6zm4 0h12v2H8V6zM4 11h2v2H4v-2zm4 0h12v2H8v-2zM4 16h2v2H4v-2zm4 0h12v2H8v-2z"/></svg>この記事の目次 <span style="float:right;font-weight:normal;font-size:.85em;color:#888;">タップで開閉</span></summary>
  <ol style="margin:0;padding:4px 18px 16px 18px;list-style:none;">
    <li style="padding:8px 0;border-top:1px solid #eee;"><span style="display:inline-block;min-width:24px;height:24px;border-radius:6px;background:#2f6690;color:#fff;text-align:center;line-height:24px;font-size:.8em;margin-right:10px;">1</span><a href="#h1" style="text-decoration:none;color:inherit;">見出し1</a></li>
    <li style="padding:8px 0;border-top:1px solid #eee;"><span style="display:inline-block;min-width:24px;height:24px;border-radius:6px;background:#2f6690;color:#fff;text-align:center;line-height:24px;font-size:.8em;margin-right:10px;">2</span><a href="#h2" style="text-decoration:none;color:inherit;">見出し2</a></li>
  </ol>
</details>
<!-- /wp:html -->
```

## 2. 吹き出し（読者の疑問を代弁する）

アイコンは人型SVG。ユーザーの顔画像があれば `<img>`（width:48 height:48 style="border-radius:50%"）に差し替えてよい。

```html
<!-- wp:html -->
<div style="display:flex;gap:12px;align-items:flex-start;margin:1.5em 0;">
  <div style="flex-shrink:0;width:48px;height:48px;border-radius:50%;background:#e8ecef;display:flex;align-items:center;justify-content:center;"><svg width="28" height="28" viewBox="0 0 24 24" fill="#8a97a3"><path d="M12 12a5 5 0 1 0-5-5 5 5 0 0 0 5 5zm0 2c-4 0-8 2-8 5v3h16v-3c0-3-4-5-8-5z"/></svg></div>
  <div style="background:#f5f5f5;border-radius:12px;padding:12px 16px;line-height:1.7;">ここに読者の疑問やセリフが入ります</div>
</div>
<!-- /wp:html -->
```

## 3. ポイント行（1行完結の要点提示・3色）

長文ボックスにするほどでもない要点を、アイコン＋太字1行＋補足で見せる。右端に日付等のメタ情報を置ける。

```html
<!-- wp:html -->
<div style="display:flex;align-items:flex-start;gap:10px;border:1px solid #f0b8b4;border-radius:10px;background:#fdecea;padding:12px 16px;margin:1em 0;">
  <svg width="18" height="18" viewBox="0 0 24 24" fill="#b3261e" style="flex-shrink:0;margin-top:3px;"><path d="M12 2 1 21h22L12 2zm1 14h-2v2h2v-2zm0-7h-2v5h2V9z"/></svg>
  <div style="flex:1;line-height:1.6;"><strong>注意の見出しをここに</strong><br><span style="font-size:.9em;color:#555;">補足説明をここに</span></div>
  <span style="font-size:.8em;color:#b3261e;white-space:nowrap;text-align:right;">2026/10<br>改定日</span>
</div>
<!-- /wp:html -->

<!-- wp:html -->
<div style="display:flex;align-items:flex-start;gap:10px;border:1px solid #bfdccb;border-radius:10px;background:#e9f4ee;padding:12px 16px;margin:1em 0;">
  <svg width="18" height="18" viewBox="0 0 24 24" fill="#2e7d4f" style="flex-shrink:0;margin-top:3px;"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm-1.2 14.5-4.3-4.3 1.4-1.4 2.9 2.9 5.9-5.9 1.4 1.4-7.3 7.3z"/></svg>
  <div style="flex:1;line-height:1.6;"><strong>チェックポイントをここに</strong><br><span style="font-size:.9em;color:#555;">補足説明をここに</span></div>
</div>
<!-- /wp:html -->

<!-- wp:html -->
<div style="display:flex;align-items:flex-start;gap:10px;border:1px solid #d4c9ee;border-radius:10px;background:#f0edfa;padding:12px 16px;margin:1em 0;">
  <svg width="18" height="18" viewBox="0 0 24 24" fill="#6246b5" style="flex-shrink:0;margin-top:3px;"><path d="M4 20V10h3v10H4zm6.5 0V4h3v16h-3zM17 20v-7h3v7h-3z"/></svg>
  <div style="flex:1;line-height:1.6;"><strong>整理・メモの見出しをここに</strong><br><span style="font-size:.9em;color:#555;">補足説明をここに</span></div>
</div>
<!-- /wp:html -->
```

## 4. 注意ボックス／まとめボックス（複数行の内容用）

```html
<!-- wp:html -->
<div style="border:1px solid #f0b8b4;border-left:6px solid #b3261e;border-radius:8px;background:#fdecea;padding:14px 18px;margin:1.5em 0;">
  <p style="margin:0 0 4px;font-weight:bold;"><svg width="16" height="16" viewBox="0 0 24 24" fill="#b3261e" style="vertical-align:-2px;margin-right:6px;"><path d="M12 2 1 21h22L12 2zm1 14h-2v2h2v-2zm0-7h-2v5h2V9z"/></svg>注意</p>
  <p style="margin:0;line-height:1.7;">ここに注意点が入ります</p>
</div>
<!-- /wp:html -->

<!-- wp:html -->
<div style="border:1px solid #c5d7e4;border-left:6px solid #2f6690;border-radius:8px;background:#eef4f8;padding:14px 18px;margin:1.5em 0;">
  <p style="margin:0 0 8px;font-weight:bold;"><svg width="16" height="16" viewBox="0 0 24 24" fill="#2f6690" style="vertical-align:-2px;margin-right:6px;"><path d="M3 17.25V21h3.75L17.8 9.94l-3.75-3.75L3 17.25zM20.7 7a1 1 0 0 0 0-1.4l-2.3-2.3a1 1 0 0 0-1.4 0l-1.8 1.8 3.75 3.75L20.7 7z"/></svg>この章のまとめ</p>
  <ul style="margin:0;padding-left:1.3em;line-height:1.9;">
    <li>要点1</li>
    <li>要点2</li>
  </ul>
</div>
<!-- /wp:html -->
```

## 5. 比較表（バッジ付き・モバイル対応・出典行つき）

- 可否は色付きバッジ＋◯×併記（色だけに頼らない）
- 外側の div でモバイル時は横スクロール（表が画面幅で潰れない）
- 数値・料金を書いたら直下に出典行を必ず付ける（SEO記事の信頼性）

```html
<!-- wp:html -->
<div style="overflow-x:auto;margin:1.5em 0;">
<table style="border-collapse:collapse;width:100%;min-width:520px;font-size:.95em;">
  <thead>
    <tr>
      <th style="background:#2f6690;color:#fff;padding:10px 14px;text-align:left;border-radius:8px 0 0 0;">項目</th>
      <th style="background:#2f6690;color:#fff;padding:10px 14px;text-align:center;">選択肢A</th>
      <th style="background:#2f6690;color:#fff;padding:10px 14px;text-align:center;border-radius:0 8px 0 0;">選択肢B</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background:#fff;"><td style="padding:10px 14px;border-bottom:1px solid #eee;font-weight:bold;">月額</td><td style="padding:10px 14px;border-bottom:1px solid #eee;text-align:center;">¥◯◯</td><td style="padding:10px 14px;border-bottom:1px solid #eee;text-align:center;">¥◯◯</td></tr>
    <tr style="background:#f7f9fb;"><td style="padding:10px 14px;border-bottom:1px solid #eee;font-weight:bold;">機能X</td><td style="padding:10px 14px;border-bottom:1px solid #eee;text-align:center;"><span style="display:inline-block;background:#fdecea;color:#b3261e;border-radius:999px;padding:2px 12px;font-size:.85em;">× 不可</span></td><td style="padding:10px 14px;border-bottom:1px solid #eee;text-align:center;"><span style="display:inline-block;background:#e9f4ee;color:#2e7d4f;border-radius:999px;padding:2px 12px;font-size:.85em;">◯ 可</span></td></tr>
  </tbody>
</table>
</div>
<!-- /wp:html -->

<!-- wp:html -->
<p style="font-size:.8em;color:#777;margin:-0.8em 0 1.5em;">出典: <a href="#" style="color:#777;">◯◯公式サイト</a>（2026年◯月 執筆時点で確認）</p>
<!-- /wp:html -->
```

## 6. おすすめ・ハイライトボックス（ヘッダーバー型）

結論やイチオシを目立たせる。ヘッダーバー＋本文の2層構造。マーカー強調は1ボックス1箇所まで。

```html
<!-- wp:html -->
<div style="border:1px solid #2f6690;border-radius:10px;overflow:hidden;margin:1.5em 0;">
  <div style="background:#2f6690;color:#fff;padding:10px 18px;font-weight:bold;text-align:center;">ここに結論・おすすめの見出し</div>
  <div style="padding:16px 18px;line-height:1.8;background:#fff;">
    本文をここに。<strong>重要な一文</strong>は太字、特に押したい一文は<mark style="background:linear-gradient(transparent 55%,#fff59d 55%);">マーカー強調</mark>を使う。
  </div>
</div>
<!-- /wp:html -->
```

## 7. CTAボックス（ボタンはセンタリング）

記事末尾や章末の行動喚起。ラベル → 見出し → 説明 → 中央ボタンの順。ボタンは1つだけ。

```html
<!-- wp:html -->
<div style="border:2px solid #2f6690;border-radius:12px;padding:24px 20px;margin:2em 0;background:#f7f9fb;text-align:center;">
  <p style="margin:0 0 8px;"><span style="display:inline-block;background:#eef4f8;color:#2f6690;border-radius:999px;padding:2px 14px;font-size:.8em;font-weight:bold;">おすすめ</span></p>
  <p style="margin:0 0 8px;font-size:1.15em;font-weight:bold;line-height:1.5;">CTAの見出しをここに</p>
  <p style="margin:0 0 16px;font-size:.95em;color:#555;line-height:1.7;">補足説明をここに。読者がボタンを押す理由を1〜2文で。</p>
  <a href="#" style="display:inline-block;background:#2f6690;color:#fff;text-decoration:none;border-radius:999px;padding:12px 32px;font-weight:bold;">ボタンのラベル →</a>
</div>
<!-- /wp:html -->
```

## 8. ステップリスト（手順の提示）

```html
<!-- wp:list {"ordered":true} -->
<ol><li><strong>手順名</strong> — 補足説明</li><li><strong>手順名</strong> — 補足説明</li></ol>
<!-- /wp:list -->
```

## 使い方の原則

- テーマ固有ブロックが regulation.md のブロックマッピング表にあるものは**そちらを優先**する
- この部品集は「表現手段がない装飾」の補完。乱用せず、regulation.md のデザイン頻度に従う
- 1記事の中で同じ意味の装飾は同じ部品を使う（注意はいつも赤、チェックはいつも緑 — 意味と色を固定する）
