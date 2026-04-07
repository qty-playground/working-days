# Samsung 螢幕設定 Script 現況與後續計畫

## 遠端機器上的 script 位置

機器：PIC-TW-DOOH-RDP（pt1 client: pic-rdp）

| 位置 | 說明 |
|------|------|
| `C:\Users\Public\Desktop\samsung_monitor_setup.ps1` | 共用原始版 |
| `C:\Users\qrtt1\Desktop\samsung_monitor_setup.ps1` | 個人複製版 |
| `C:\Users\qrtt1\Desktop\Backup\samsung_monitor_setup.ps1` | 備份 |

三份幾乎相同，唯一差異：qrtt1 版把某段 `Start-Sleep` 從 15 秒改為 10 秒。

已透過 S3 relay 拉回本地，放在 `scripts/` 目錄。

## 為什麼不能直接執行

原始 script 設計為在 RDP Server 上手動開 PowerShell 執行，整個流程是一條龍跑完。透過 pt1 遠端執行會有限制：
- script 內部用 `New-PSSession` 建立到門市主機的 PSSession，再用 `Invoke-Command` 送指令
- pt1 本身就是遠端執行，等於要做「遠端的遠端」（double hop），可能遇到認證或 session 問題
- script 有互動性的等待和多段 sleep，不適合一次性送出

## 後續計畫

拆解 script 為獨立步驟，逐步透過 pt1 執行：

1. 取得 viewer 檔連線資訊（IP、帳密）
2. 建立 PSSession 到門市主機
3. 設定乙太網路 2 靜態 IP
4. 驗證主機與螢幕連線（ping）
5. 透過 TCP:1515 發送 Samsung MDC 指令（network standby、亮度、重啟、關閉、開啟）

每個步驟獨立送出、確認結果後再進下一步，比一條龍更可控。
