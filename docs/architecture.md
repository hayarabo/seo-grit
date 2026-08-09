# seo-grit アーキテクチャ

> 最終更新: 2026-08-09（Day 3）

## 最終形: 独立した OSS Web アプリ

seo-grit は「Claude Code のプラグイン」ではなく、**独立した OSS Web アプリケーション**として開発する。
Cloudflare 無料枠でセルフホストでき、全機能を REST API として公開し、MCP サーバーを同梱して
Claude Code から自然言語で操作できる構成を目指す。

### 構成（将来図）

| レイヤー | 役割 |
|---|---|
| apps/worker | API 本体（記事・リライト・計測）。Cloudflare Workers 想定 |
| apps/web | ダッシュボード（新規記事・リライト・GSC/GA4 計測を1画面で） |
| packages/db | ナレッジ・レギュレーション・記事・計測データのスキーマ（D1 想定） |
| packages/mcp-server | Claude Code 連携。壁打ち・執筆・入稿を自然言語で操作 |
| packages/create-seo-grit | `npx create-seo-grit` 一発セットアップ CLI |

- AI 本体はローカルの Claude Code。seo-grit の API / MCP を通じて実作業を行う
- 記事の公開先は WordPress REST API（アプリケーションパスワード認証）。WP プラグインは作らない
- ユーザーデータ（ナレッジ・トンマナ・WP 認証情報・記事）は**各ユーザーが自分でデプロイした環境の DB にのみ存在する**。
  リポジトリにユーザーデータが入る余地を構造的になくす

## Phase 1 の位置づけ: ローカル試作で「核」を検証する

製品の核は「壁打ち → 一次情報 × AI の記事生成」。器（Web アプリ）より先にここを検証する。

- Phase 1 は Claude Code のスキル（`skills/`）+ シェルスクリプト（`scripts/`）で核のフローを動かす
- ここで磨いたプロンプト設計・フロー設計が、そのまま将来の apps/worker / mcp-server の中身になる
- **試作段階でもユーザーデータはリポジトリ外に置く**。Claude Code をユーザー自身の作業ディレクトリ
  （リポジトリの外。例: `~/my-media/`）で起動し、スキルはカレントディレクトリにデータを生成する。
  リポジトリ内の `data/` ディレクトリ方式（gitignore 同居）は Day 3 で廃止した

## データ分離の原則

1. このリポジトリに入るのは**仕組みだけ**: skills / templates / scripts / docs
2. ユーザー固有情報（プロフィール・参考メディア・トンマナ・WP URL/認証情報・生成記事）は
   リポジトリの外にしか存在させない。「gitignore で隠す」ではなく「同居させない」
3. 公開してよい文書だけを docs/ に置く。検討中のドラフト・私物メモはリポジトリ外（開発者は private/ 運用）
