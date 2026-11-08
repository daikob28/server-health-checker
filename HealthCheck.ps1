<#
.SYNOPSIS
    サーバー死活監視 ＆ イベントログ抽出スクリプト
.DESCRIPTION
    指定したサーバーに対してPing疎通確認を行い、さらにWindowsイベントログから
    直近のエラー・警告レベルのログを抽出して表示します。
#>

# 1. 監視対象のサーバー（IPアドレスまたはホスト名）のリスト
$Targets = @(
    "localhost"     # ※リモートサーバーを指定する場合はWinRMや権限設定が必要です
)

Write-Host "=== 統合インフラ点検スクリプト開始: $(Get-Date) ===" -ForegroundColor Cyan
Write-Host ""

foreach ($Target in $Targets) {
    Write-Host "--------------------------------------------------"
    Write-Host "■ 対象サーバー: $Target" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------"

    # --- ① Pingによる死活監視 ---
    $PingResult = Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($PingResult) {
        Write-Host "[OK] Ping応答: 正常" -ForegroundColor Green
    } else {
        Write-Host "[NG] Ping応答: 疎通なし（以降のイベントログ取得をスキップします）" -ForegroundColor Red
        Write-Host ""
        continue
    }

    # --- ② Windowsイベントログ（System）からエラー・警告を抽出 ---
    Write-Host "-> 直近24時間のシステムイベントログ（Error / Warning）を確認中..." -ForegroundColor Gray
    
    try {
        # 過去24時間以内に発生したSystemログの「Error(1)」と「Warning(2)」を抽出
        $TimeAfter = (Get-Date).AddHours(-24)
        $EventLogs = Get-WinEvent -ComputerName $Target -FilterHashtable @{
            LogName   = 'System'
            Level     = @(1, 2) # 1: Critical/Error, 2: Warning
            StartTime = $TimeAfter
        } -ErrorAction Stop | Select-Object -First 5 # 上位5件までを表示

        if ($EventLogs) {
            Write-Host "[!] 該当するイベントログが見つかりました:" -ForegroundColor Yellow
            foreach ($Log in $EventLogs) {
                Write-Host "  - 発生時刻: $($Log.TimeCreated)"
                Write-Host "    レベル: $($Log.LevelDisplayName) [ID: $($Log.Id)]"
                Write-Host "    メッセージ: $($Log.Message.Trim())" -ForegroundColor DarkYellow
                Write-Host "    ----------------------------------------------"
            }
        } else {
            Write-Host "[OK] 直近24時間にエラー・警告レベルのログはありません。" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[情報] イベントログの取得に失敗したか、ログが存在しません（権限やWinRM設定の可能性があります）。" -ForegroundColor DarkGray
    }

    Write-Host ""
}

Write-Host "=== 統合インフラ点検スクリプト終了 ===" -ForegroundColor Cyan