# tiktok-auto-kit 導入スクリプト（Windows）
#
#   powershell -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/autotik-lab/tiktok-auto-setup/main/setup.ps1))) <取得キー>"
#
# やること: 環境の確認 → キット（限定公開リポジトリの zip）を取得キーで取得 → %USERPROFILE%\tiktok-auto に展開（既にあれば上書き）
#           → .kit-token を保存 → install.ps1 を実行 → .env をメモ帳で開く
# 同じコマンドを貼り直しても壊れない（再導入・更新になる）。data\・参照ファイル・.env・engine\.venv は残る。
# このスクリプトに秘密は入っていない。取得キーは引数で受け取り、tiktok-auto\.kit-token 以外には書かない。
# PowerShell 5.1 と 7 の両方で動く記法にする。

param([string]$Token = "")

$ErrorActionPreference = "Stop"
$ZipUrl = "https://api.github.com/repos/autotik-lab/tiktok-auto-kit/zipball/main"
$Dest = Join-Path $HOME "tiktok-auto"
$TmpZip = Join-Path $HOME "tiktok-auto-kit.zip"
$TmpDir = Join-Path $HOME "tiktok-auto-kit_tmp"
$MinFreeGB = 3

function Say($m) { Write-Host $m }
function Step($m) { Write-Host ""; Write-Host "== $m" }
function Fail($m, $next) {
  Write-Host ""
  Write-Host "!! $m" -ForegroundColor Red
  if ($next) { Write-Host "   -> $next" -ForegroundColor Yellow }
  if (Test-Path $TmpZip) { Remove-Item $TmpZip -Force -ErrorAction SilentlyContinue }
  if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue }
  exit 1
}

try {
  Say "tiktok-auto-kit setup (Windows)"

  # 1. 環境の確認
  Step "環境を確認します"
  if ($env:OS -ne "Windows_NT") { Fail "このコマンドは Windows 用です。" "Mac の方は会員サイトの Mac 用コマンドをターミナルに貼ってください" }
  if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") { Fail "この PC（ARM 版 Windows）は対応外です。" "Windows 64bit（x64）の PC で実行してください" }
  if ($PSVersionTable.PSVersion.Major -lt 5) { Fail "PowerShell が古すぎます（5.1 以上が必要）。" "Windows Update を実行するか、PowerShell 7（https://aka.ms/powershell）を入れてください" }
  if (-not $Token) { Fail "取得キーがありません。" "会員サイトのコマンドを、末尾まで含めてそのままコピーして貼り直してください" }
  if ($Token -match "[<>]") { Fail "取得キーがプレースホルダのままです。" "会員サイトに表示されているコマンドをそのまま貼ってください" }
  $drive = (Get-Item $HOME).PSDrive
  if ($drive -and $null -ne $drive.Free -and $drive.Free -lt ($MinFreeGB * 1GB)) { Fail "空き容量が足りません（$MinFreeGB GB 以上必要）。" "不要なファイルを消してから貼り直してください" }
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
  try { Invoke-WebRequest -Uri "https://api.github.com" -UseBasicParsing -TimeoutSec 15 | Out-Null }
  catch { Fail "インターネットに接続できません。" "Wi-Fi やプロキシの設定を確認してから、同じコマンドを貼り直してください" }
  Say "OK: Windows / PowerShell $($PSVersionTable.PSVersion) / 空き容量 / 接続"
  # Git for Windows は Claude Desktop の Code タブに必須（導入自体には不要なので止めない）
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host "注意: git が見つかりません。Claude Desktop の Code タブには Git for Windows（https://git-scm.com/download/win）が必要です。導入後に Claude Desktop を再起動してください" -ForegroundColor Yellow }

  # 2. 取得
  Step "キットを取得します（約 5 MB）"
  try {
    Invoke-WebRequest -Uri $ZipUrl -Headers @{ Authorization = "Bearer $Token"; Accept = "application/vnd.github+json" } -UserAgent "tiktok-auto-setup" -OutFile $TmpZip -UseBasicParsing -TimeoutSec 120
  } catch {
    $code = 0
    try { $code = [int]$_.Exception.Response.StatusCode } catch {}
    if ($code -in 401, 403, 404) { Fail "取得キーが無効か、取得先が変わっています（HTTP ${code}）。" "会員サイトの最新のコマンドをコピーして貼り直してください。それでも出る場合は会員サイトの「お知らせ」を確認してください" }
    Fail "ダウンロードに失敗しました。" "少し待ってから、同じコマンドを貼り直してください"
  }
  if (-not (Test-Path $TmpZip) -or (Get-Item $TmpZip).Length -lt 100000) { Fail "取得したファイルが壊れています。" "同じコマンドを貼り直してください" }
  Say "OK: 取得"

  # 3. 展開（既存フォルダには上書き。data\・参照ファイル・.env・.venv は zip に無いので残る）
  Step "$Dest に展開します"
  $before = ""
  if (Test-Path (Join-Path $Dest "VERSION")) { $before = [IO.File]::ReadAllText((Join-Path $Dest "VERSION"), [Text.Encoding]::UTF8).Trim() }
  if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force }
  Expand-Archive -Path $TmpZip -DestinationPath $TmpDir -Force
  $src = Get-ChildItem $TmpDir -Directory | Select-Object -First 1
  if (-not $src) { Fail "取得したファイルの構造が想定と違います。" "同じコマンドを貼り直してください" }
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Get-ChildItem -Path $src.FullName -Force | ForEach-Object {
    $target = Join-Path $Dest $_.Name
    if ($_.PSIsContainer) {
      if (-not (Test-Path $target)) { New-Item -ItemType Directory -Force -Path $target | Out-Null }
      Copy-Item -Path (Join-Path $_.FullName "*") -Destination $target -Recurse -Force
    } else {
      Copy-Item -Path $_.FullName -Destination $target -Force
    }
  }
  Remove-Item $TmpZip -Force
  Remove-Item $TmpDir -Recurse -Force
  if (-not (Test-Path (Join-Path $Dest "install.ps1"))) { Fail "展開後に install.ps1 が見つかりません。" "同じコマンドを貼り直してください" }
  [System.IO.File]::WriteAllText((Join-Path $Dest ".kit-token"), $Token + "`n", (New-Object System.Text.UTF8Encoding $false))
  $after = [IO.File]::ReadAllText((Join-Path $Dest "VERSION"), [Text.Encoding]::UTF8).Trim()
  if ($before -and $before -ne $after) { Say "OK: 展開（更新 $before -> ${after}）" } else { Say "OK: 展開（VERSION ${after}）" }

  # 4. 一括導入
  Step "一括導入を実行します（初回は 10 分以上かかることがあります。画面が止まって見えても閉じずに待ってください）"
  & powershell -ExecutionPolicy Bypass -File (Join-Path $Dest "install.ps1")
  if ($LASTEXITCODE -ne 0) { Fail "一括導入で NG がありました。" "上に表示された -> の案内に従って直し、同じコマンドを貼り直してください（直っていれば続きから進みます）" }

  # 5. .env（API キーの置き場所）。未記入なら開く
  Step "仕上げ"
  $envFile = Join-Path $Dest ".env"
  # PowerShell 5.1 の Get-Content は BOM 無し UTF-8 を ANSI として読むので、UTF-8 を明示して読む（5.1 / 7 共通）
  $needKey = (Test-Path $envFile) -and (([IO.File]::ReadAllText($envFile, [Text.Encoding]::UTF8)) -match "PEXELS_API_KEY=ここに貼る")
  if ($needKey) {
    Start-Process notepad.exe -ArgumentList "`"$envFile`""
    Say ""
    Say "導入完了。メモ帳で .env が開きました。"
    Say "次にやること:"
    Say "  1. https://www.pexels.com/api/ でアカウントを作り『Your API Key』をコピー"
    Say "  2. 開いたファイルの PEXELS_API_KEY=ここに貼る の「ここに貼る」をそのキーに置き換えて保存（前後に空白や引用符を入れない）"
    Say "  3. Claude Desktop の Code タブで $Dest を開き、会員サイトの指示文 1-1 を貼る"
    Say "     Claude Desktop をすでに開いている場合は、一度完全に終了してから開き直してください（新しく入れた道具を認識させるため）"
  } else {
    Say ""
    if ($before -and $before -ne $after) { Say "更新完了（$before -> ${after}）。参照ファイル・投稿ログ・.env はそのまま残っています。" }
    else { Say "導入完了（VERSION ${after}）。.env は記入済みです。" }
    Say "次にやること: Claude Desktop の Code タブで $Dest を開き、会員サイトの指示文を貼る"
    Say "  Claude Desktop をすでに開いている場合は、一度完全に終了してから開き直してください（新しく入れた道具を認識させるため）"
  }
} catch {
  $msg = $_.Exception.Message
  if (-not $msg) { $msg = "$_" }
  Fail ("予期しないエラー: " + $msg) "同じコマンドを貼り直してください。繰り返す場合はこの画面の内容を添えて問い合わせてください"
}
