#!/usr/bin/env bash
# tiktok-auto-kit 導入スクリプト（macOS）
#
#   curl -fsSL https://raw.githubusercontent.com/autotik-lab/tiktok-auto-setup/main/setup.sh | bash -s -- <取得キー>
#
# やること: 環境の確認 → キット（限定公開リポジトリの zip）を取得キーで取得 → ~/tiktok-auto に展開（既にあれば上書き）
#           → .kit-token を保存 → install.sh を実行 → .env をテキストエディタで開く
# 同じコマンドを貼り直しても壊れない（再導入・更新になる）。data/・参照ファイル・.env・engine/.venv は残る。
# このスクリプトに秘密は入っていない。取得キーは引数で受け取り、~/tiktok-auto/.kit-token 以外には書かない。

set -u

main() {
  local TOKEN="${1:-}"
  local ZIP_URL="https://api.github.com/repos/autotik-lab/tiktok-auto-kit/zipball/main"
  local DEST="$HOME/tiktok-auto"
  local TMP_ZIP="$HOME/tiktok-auto-kit.zip"
  local MIN_FREE_GB=3

  say()  { printf '%s\n' "$*"; }
  step() { printf '\n== %s\n' "$*"; }
  fail() {
    printf '\n!! %s\n' "$1" >&2
    [ -n "${2:-}" ] && printf '   → %s\n' "$2" >&2
    rm -f "$TMP_ZIP"
    exit 1
  }

  say "tiktok-auto-kit setup (macOS)"

  # 1. 環境の確認
  step "環境を確認します"
  [ "$(uname -s)" = "Darwin" ] || fail "このコマンドは Mac 用です。" "Windows の方は会員サイトの Windows 用コマンドを PowerShell に貼ってください"
  [ -n "$TOKEN" ] || fail "取得キーがありません。" "会員サイトのコマンドを、末尾まで含めてそのままコピーして貼り直してください"
  case "$TOKEN" in *"<"*|*">"*) fail "取得キーがプレースホルダのままです。" "会員サイトに表示されているコマンドをそのまま貼ってください";; esac
  command -v curl >/dev/null 2>&1 || fail "curl が見つかりません。" "macOS には標準で入っています。OS を更新してください"
  command -v tar  >/dev/null 2>&1 || fail "tar が見つかりません。" "macOS には標準で入っています。OS を更新してください"
  local free_kb
  free_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
  if [ -n "$free_kb" ] && [ "$free_kb" -lt $((MIN_FREE_GB * 1024 * 1024)) ]; then
    fail "空き容量が足りません（${MIN_FREE_GB} GB 以上必要）。" "不要なファイルを消してから貼り直してください"
  fi
  if ! curl -fsS --max-time 15 -o /dev/null https://api.github.com; then
    fail "インターネットに接続できません。" "Wi-Fi やプロキシの設定を確認してから、同じコマンドを貼り直してください"
  fi
  say "OK: macOS / 空き容量 / 接続"

  # 2. 取得
  step "キットを取得します（約 5 MB）"
  local http
  http=$(curl -sL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" -o "$TMP_ZIP" -w '%{http_code}' "$ZIP_URL" </dev/null) || http="000"
  case "$http" in
    200) ;;
    401|403|404) fail "取得キーが無効か、取得先が変わっています（HTTP ${http}）。" "会員サイトの最新のコマンドをコピーして貼り直してください。それでも出る場合は会員サイトの「お知らせ」を確認してください";;
    000) fail "ダウンロード中に接続が切れました。" "少し待ってから、同じコマンドを貼り直してください";;
    *)   fail "ダウンロードに失敗しました（HTTP ${http}）。" "少し待ってから、同じコマンドを貼り直してください";;
  esac
  tar -tf "$TMP_ZIP" >/dev/null 2>&1 || fail "取得したファイルが壊れています。" "同じコマンドを貼り直してください"
  say "OK: 取得"

  # 3. 展開（既存フォルダには上書き。data/・参照ファイル・.env・.venv は zip に無いので残る）
  step "$DEST に展開します"
  local before=""
  [ -f "$DEST/VERSION" ] && before=$(tr -d '[:space:]' < "$DEST/VERSION")
  mkdir -p "$DEST" || fail "フォルダを作れません: $DEST" "ホームフォルダに書き込めるか確認してください"
  tar -xf "$TMP_ZIP" --strip-components=1 -C "$DEST" || fail "展開に失敗しました。" "同じコマンドを貼り直してください"
  rm -f "$TMP_ZIP"
  [ -f "$DEST/install.sh" ] || fail "展開後に install.sh が見つかりません。" "同じコマンドを貼り直してください"
  printf '%s\n' "$TOKEN" > "$DEST/.kit-token" && chmod 600 "$DEST/.kit-token"
  local after
  after=$(tr -d '[:space:]' < "$DEST/VERSION")
  if [ -n "$before" ]; then say "OK: 展開（更新 $before → ${after}）"; else say "OK: 展開（VERSION ${after}）"; fi

  # 4. 一括導入（uv → Python 3.11 → 依存 → .env の雛形 → 参照ファイルの空枠 → data/ → 許可ルール → 導入チェック）
  step "一括導入を実行します（初回は数分かかります。画面が止まって見えても待ってください）"
  if ! bash "$DEST/install.sh" </dev/null; then
    fail "一括導入で NG がありました。" "上に表示された → の案内に従って直し、同じコマンドを貼り直してください（直っていれば続きから進みます）"
  fi

  # 5. .env（API キーの置き場所）。未記入なら開く
  step "仕上げ"
  if grep -q 'PEXELS_API_KEY=ここに貼る' "$DEST/.env" 2>/dev/null; then
    open -e "$DEST/.env" 2>/dev/null || true
    say ""
    say "導入完了。テキストエディタで .env が開きました。"
    say "次にやること:"
    say "  1. https://www.pexels.com/api/ でアカウントを作り『Your API Key』をコピー"
    say "  2. 開いたファイルの PEXELS_API_KEY=ここに貼る の「ここに貼る」をそのキーに置き換えて保存（前後に空白や引用符を入れない）"
    say "  3. Claude Desktop の Code タブで次のフォルダを開き、会員サイトの指示文 1-1 を貼る"
    say "     ${DEST}"
    say "     （フォルダ選択の画面で ⌘+Shift+G を押し、~/tiktok-auto と入力すると開けます）"
  else
    say ""
    if [ -n "$before" ] && [ "$before" != "$after" ]; then
      say "更新完了（$before → ${after}）。参照ファイル・投稿ログ・.env はそのまま残っています。"
    else
      say "導入完了（VERSION ${after}）。.env は記入済みです。"
    fi
    say "次にやること: Claude Desktop の Code タブで ${DEST} を開き（⌘+Shift+G → ~/tiktok-auto）、会員サイトの指示文を貼る"
  fi
}

main "$@"
