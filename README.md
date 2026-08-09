# seo-grit

SEO記事の制作からメディア運営をClaude Codeで自動化するツール

一次情報 × AI で「その人にしか書けない記事」を作り、WordPress への入稿までを自動化することを目指しています。最終形は独立した OSS Web アプリです（[docs/architecture.md](docs/architecture.md)）。現在はフェーズ1（ローカルの Claude Code 上で動く最小構成）を開発中です。

## ディレクトリ構成

```
skills/      スキル定義（Claude Code から呼び出すプロンプト資産）
scripts/     実行スクリプト（WordPress REST API での入稿など）
templates/   作業フォルダに生成されるユーザーデータファイルの雛形
docs/        設計資料（決定事項のみ）
```

このリポジトリに入るのは**仕組みだけ**です。ユーザーデータ（ナレッジ・トンマナ・WP 接続情報・記事）は、ユーザー自身の**作業フォルダ**（このリポジトリの外）に生成され、リポジトリには一切入りません。

## 使い方（フェーズ1・開発中）

```
mkdir ~/my-media && cd ~/my-media   # 作業フォルダを作って移動（場所と名前は自由）
claude                              # そこで Claude Code を起動
```

1. `/grit-setup` — 公式サイト・SNS の URL からナレッジ・メディア設定・レギュレーションを生成
2. `/grit-write <キーワード>` — 壁打ち → 構成案 → 執筆 → WordPress 下書き入稿

WordPress 入稿には、作業フォルダに `.env`（[.env.example](.env.example) 参照）が必要です。
