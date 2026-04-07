# Samsung v2 Local Variant - 繞過 PSSession

## What happened

PIC2400160（中航）的 PSSession Access Denied 查不出原因。WinRM 兩端設定都正常，帳密跟能連的 admin.ps1 一致。

決定換策略：既然 pt1 已經裝在目標機上，直接在本機執行 setup，不需要 PSSession。

## What we built

`scripts/samsung_monitor_setup_v2_local.ps1` — v2 的 local 版本：
- 移除 Section 1（viewer parsing + PSSession），所有指令直接本機執行
- Send-DisplayQuery / Send-DisplayCommand 不再透過 Invoke-Command
- Set-NetworkIP 直接操作本機網卡
- 保留 -Apply flag 和 transcript logging

## Current state

- Script 寫好，尚未上傳測試
- pt1 client 在目標機上是 ONLINE（client ID: `client`，hostname: F0B6EBED0542）
- Ethernet 2 (ifIndex 12) 現況：DHCP, APIPA 169.254.146.224（尚未設定靜態 IP）
- 這台只有 2 張網卡（正式環境標準配置）

## 下次從這裡開始

1. 用 S3 relay 把 samsung_monitor_setup_v2_local.ps1 傳到 client
2. 先跑 dry-run 確認 query 正常
3. 跑 -Apply 執行設定
4. 比對 pre/post setup state
5. 記錄結果，如果成功就確認 local 版本是可行的替代方案
6. Access Denied 問題仍需後續追查（可能是 pt1 relay 的密碼 escaping）

## Reflection

情境：PSSession Access Denied 查了 WinRM 設定、帳密、port 都正常，但就是連不上。同時 pt1 client 已經裝在目標機上。
決策：寫一個 local 版本直接在目標機執行，繞過 PSSession。
為什麼：繼續追 Access Denied 根因需要更多時間，但設定螢幕是當下的目標。pt1 已在目標機上，local 版本可以立即完成任務。Access Denied 的 debug 可以之後再做，不阻塞當前工作。

情境：v2 local 版本要怎麼處理跟原版 v2 的關係。
決策：獨立檔案 `samsung_monitor_setup_v2_local.ps1`，不修改原版 v2。
為什麼：兩個版本適用不同場景 — 原版透過 RDP Server 集中管理多台門市主機，local 版本在有 pt1 的情況下直接操作。保留兩個版本，未來可以根據實際部署情況選擇。
