# Samsung 螢幕遠端設定 Script 研究筆記

## 背景

DOOH（Digital Out-of-Home）門市顯示器的遠端設定自動化腳本，改寫自 Spark 提供的版本。目的是在完成實體接線與設定電視 IP 後，透過 script 一鍵完成設定與驗證。

## 架構概要

操作環境：DOOH RDP Server → 透過 PowerShell Remoting 連到門市主機 → 主機透過 TCP 控制 Samsung 螢幕

```
[RDP Server] --PSSession--> [門市主機] --TCP:1515--> [Samsung 螢幕 172.31.255.254]
```

## Script 做了什麼

腳本名稱：`samsung_monitor_setup.ps1`，放在 RDP Server 的 `C:\Users\Public\Desktop\`

### 1. 取得連線資訊
- 自動從使用者 Downloads 目錄找最新的 `*_viewer.ps1` 檔
- 用 regex 從 viewer 檔中擷取：門市主機 IP、使用者名稱、OP_admin 密碼
- 建立 PSSession 到門市主機

### 2. 設定門市主機「乙太網路 2」靜態 IP
- IP: `172.31.255.253`，Subnet: `/30`（255.255.255.252）
- 停用 DHCP → 移除現有 IP → 設定新 IP
- 有 fallback：PowerShell cmdlet 失敗時改用 `netsh`

### 3. 驗證主機與螢幕連線
- Ping `172.31.255.254`（螢幕 IP）
- 失敗時自動做診斷：檢查網卡狀態、IP 設定、ARP 表

### 4. 透過 Samsung MDC Protocol 設定螢幕
透過 TCP port 1515 發送 hex 指令（Samsung Multiple Display Control protocol）：

| 動作 | 發送指令 | 預期回應 |
|------|---------|---------|
| 設定 network standby | AA B5 00 01 01 B7 | AA FF 00 03 41 B5 01 F9 |
| 設定亮度 80 | AA 57 00 08 06 00 01 50 06 00 00 00 BC | AA FF 00 0A 41 57 06 00 01 50 06 00 00 00 FE |
| 重啟螢幕 | AA 11 00 01 02 14 | AA FF 00 03 41 11 02 56 |
| 關閉螢幕 | AA 11 00 01 00 12 | AA FF 00 03 41 11 00 54 |
| 開啟螢幕 | AA 11 00 01 01 13 | AA FF 00 03 41 11 01 55 |

每個步驟之間有 sleep（5~30 秒）等螢幕反應。

### 5. 流程結果
- 全部成功 → 完成
- 任一步驟失敗 → 直接重跑整個 script

## 值得注意的設計

- viewer 檔自動探索：不需手動輸入 IP/密碼，從最新下載的 viewer 檔自動抓
- Samsung MDC protocol 是二進位協定，每個指令有固定格式（header AA + command + id + data length + data + checksum）
- 回應驗證是逐 byte 比對 hex string，嚴格匹配
- 網路設定的 /30 subnet 表示只有主機和螢幕兩個 IP（.253 和 .254）

## 使用流程

1. 從門市管理後台下載最新的 viewer 檔到 Downloads
2. 以管理員權限開 PowerShell
3. 執行 `.\samsung_monitor_setup.ps1`
4. 觀察輸出，確認所有步驟成功
5. 失敗就重跑
