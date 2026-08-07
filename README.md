# seo-grit

SEO記事の制作からメディア運営をClaude Codeで自動化するツール

一次情報 × AI で「その人にしか書けない記事」を作り、WordPress への入稿までを自動化することを目指しています。現在はフェーズ1（ローカルの Claude Code 上で動く最小構成）を開発中です。

## ディレクトリ構成

```
skills/      スキル定義（Claude Code から呼び出すプロンプト資産）
scripts/     実行スクリプト（WordPress REST API での入稿など）
templates/   data/ に生成されるユーザーデータファイルの雛形
docs/        設計資料（決定事項のみ）
data/        ユーザーデータ（ナレッジ・メディア設定・記事）… git 管理外
```

## セットアップ（開発中）

```
cp .env.example .env   # WordPress の接続情報を記入
```
