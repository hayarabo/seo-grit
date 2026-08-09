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

## 前提条件

- WordPress サイトを持っていること（WP 5.6+。サイト構築自体は seo-grit のスコープ外です）
- [Claude Code](https://claude.com/claude-code) が使えること

## セットアップ（フェーズ1・開発中）

```
git clone https://github.com/hayarabo/seo-grit.git && seo-grit/scripts/install.sh
```

スキルが Claude Code に登録されます。あとは作業フォルダを作って始めるだけ:

```
mkdir -p ~/my-media && cd ~/my-media   # 作業フォルダ（場所と名前は自由）
claude                                 # そこで Claude Code を起動
```

1. `/grit-setup` — 公式サイト・SNS の読み込み → ナレッジ・メディア設定・レギュレーション生成 → WordPress 接続テストまで一気通貫のオンボーディング
2. `/grit-write <キーワード>` — 壁打ち → 構成案 → 執筆 → デザイン付与 → WordPress 下書き入稿
