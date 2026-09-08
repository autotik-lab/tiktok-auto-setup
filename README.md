# tiktok-auto-setup

tiktok-auto-kit（全自動TikTok運用システム 完全実装キット）の導入スクリプト。
キット本体は限定公開リポジトリにあり、会員サイトに表示される取得キーが無いと取得できません。
このリポジトリには導入の手順（スクリプト）だけがあり、秘密は含まれていません。

## 使い方（会員サイトに表示されるコマンド）

macOS（ターミナル）:

```
curl -fsSL https://raw.githubusercontent.com/autotik-lab/tiktok-auto-setup/main/setup.sh | bash -s -- <取得キー>
```

Windows（PowerShell。コマンドプロンプトに貼っても動く）:

```
powershell -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/autotik-lab/tiktok-auto-setup/main/setup.ps1))) <取得キー>"
```

## スクリプトがやること

1. 環境の確認（OS・空き容量 3 GB・インターネット接続）
2. キットの zip を取得キーで取得（HTTP 401 / 403 / 404 なら「取得キーが無効」と表示して止まる）
3. `~/tiktok-auto`（Windows は `%USERPROFILE%\tiktok-auto`）に展開。既にあれば上書き（再導入・更新）。`data/`・参照ファイル・`.env`・`engine/.venv` は zip に無いので残る
4. 取得キーを `~/tiktok-auto/.kit-token` に保存（更新スキルが使う）
5. `install.sh` / `install.ps1` を実行（uv → Python 3.11 → 依存 → `.env` の雛形 → 参照ファイルの空枠 → `data/` → 許可ルール → 導入チェック）
6. `.env` が未記入ならテキストエディタで開き、次にやることを表示

同じコマンドを貼り直しても壊れません。途中で止まった場合は表示された案内に従って貼り直してください。

## 開発者メモ

- `main` は保護し、組織メンバー以外が変更できないようにする
- ここにはスクリプトと本 README 以外を置かない（キットの説明・設計・ノウハウは入れない）
- 開発元は `フロントシステム/tiktok-auto-setup/`。変更したらここへ push する
