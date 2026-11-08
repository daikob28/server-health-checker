<#
.SYNOPSIS
    サーバー死活監視 ＆ イベントログ抽出（ファイル自動保存機能付き）
.DESCRIPTION
    指定したサーバーに対してPing疎通確認を行い、Windowsイベントログから
    直近のエラー・警告レベルのログを抽出。さらに結果を日時付きのテキストファイルに出力します。
#>

# 0. ログファイルの出力設定（スクリプトのある場所に "Logs" フォルダを強制作成）
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = $PSScriptRoot }
if (-not $ScriptDir) { $ScriptDir = Get-Location }

$LogDir = Join-Path $ScriptDir "Logs"

# フォルダが存在しない場合は確実に作成する
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "HealthCheck_Report_$Timestamp.txt"

# コンソール出力とファイル出力を同時に行うための関数
function Write-Log {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $Message
}

# 1. 監視対象のサーバー（IPアドレスまたはホスト名）のリスト
$Targets = @(
    "localhost"     # 必要に応じてサーバーを追加・変更してください
)

Write-Log "=== 統合インフラ点検スクリプト開始: $(Get-Date) ===" "Cyan"
Write-Log ""

foreach ($Target in $Targets) {
    Write-Log "--------------------------------------------------" "Yellow"
    Write-Log "■ 対象サーバー: $Target" "Yellow"
    Write-Log "--------------------------------------------------" "Yellow"

    # --- ① Pingによる死活監視 ---
    $PingResult = Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($PingResult) {
        Write-Log "[OK] Ping応答: 正常" "Green"
    } else {
        Write-Log "[NG] Ping応答: 疎通なし（以降のイベントログ取得をスキップします）" "Red"
        Write-Log ""
        continue
    }

    # --- ② Windowsイベントログ（System）からエラー・警告を抽出 ---
    Write-Log "-> 直近24時間のシステムイベントログ（Error / Warning）を確認中..." "DarkGray"
    
    try {
        $TimeAfter = (Get-Date).AddHours(-24)
        $EventLogs = Get-WinEvent -ComputerName $Target -FilterHashtable @{
            LogName   = 'System'
            Level     = @(1, 2) # 1: Critical/Error, 2: Warning
            StartTime = $TimeAfter
        } -ErrorAction Stop | Select-Object -First 5

        if ($EventLogs) {
            Write-Log "[!] 該当するイベントログが見つかりました:" "Yellow"
            foreach ($Log in $EventLogs) {
                Write-Log "  - 発生時刻: $($Log.TimeCreated)" "White"
                Write-Log "    レベル: $($Log.LevelDisplayName) [ID: $($Log.Id)]" "White"
                Write-Log "    メッセージ: $($Log.Message.Trim())" "DarkYellow"
                Write-Log "    ----------------------------------------------" "White"
            }
        } else {
            Write-Log "[OK] 直近24時間にエラー・警告レベルのログはありません。" "Green"
        }
    }
    catch {
        Write-Log "[情報] イベントログの取得に失敗したか、ログが存在しません（権限やWinRM設定の可能性があります）。" "DarkGray"
    }

    Write-Log ""
}

Write-Log "=== 統合インフラ点検スクリプト終了 ===" "Cyan"
Write-Host ""
Write-Host "📁 レポートファイルが保存されました: $LogFile" -ForegroundColor Green