# Samsung v2 Local - Live Test on PIC2400160

## v2_local 實測結果

透過 S3 relay 上傳 `samsung_monitor_setup_v2_local.ps1` 到 client (F0B6EBED0542)，實測成功。

PRE vs POST 比較：

| 項目 | PRE | POST |
|------|-----|------|
| Ethernet 2 IP | 169.254.146.224 (APIPA/DHCP) | 172.31.255.253/30 (Static) |
| MDC Power | timeout (螢幕不可達) | ON, ACK OK |
| MDC Network Standby | timeout | ON, verify OK |
| MDC Brightness | timeout | 80, verify OK |
| Restart/OFF/ON cycle | — | 全部 ACK + verify OK |

結論：v2_local 是可行的替代方案，繞過 PSSession 直接在門市主機上執行。

## WinRM Access Denied 深入排查

嘗試修復 PSSession Access Denied（從 pic-rdp → 192.168.1.116），做了以下調整但全部無效：

1. `LocalAccountTokenFilterPolicy = 1` — 設定成功，無效
2. WinRM Listener 刪除重建 — 完成，無效
3. Network Profile 從 Public 改 Private — 完成，無效
4. WinRM Firewall Rules 啟用 — 完成，無效
5. `Enable-PSRemoting -Force` — 回報已設定，無效
6. `winrm quickconfig -force` — 回報已設定，無效
7. WinRM 服務重啟 — 完成，無效

手動在 pic-rdp 上輸入密碼測 PSSession 也不行。

參考另一台 F0B6EBED10CB 的排查報告（~/Downloads/dddd/），該台的 root cause 是 LocalAccountTokenFilterPolicy + Listener 遺失，修完就好了。但 PIC2400160 做了同樣修復仍不行。

## 關鍵發現

- RDP (3389) 可以連，WinRM (5985) 不行 — 兩者認證路徑不同
- admin script 的 Invoke-Command 可能也失敗了，只是錯誤被吞（RDP 檔在 Invoke-Command 前就產生）
- Ansible 也報 `ntlm: the specified credentials were rejected by the server`
- `Password last set: 2026-04-07 11:15 AM` — 密碼今天改過，但 RDP 用同密碼可連
- Security Event Log 只有一筆 2025-12 的 POS 帳號失敗，沒有 OP_Admin 的失敗紀錄

## 待查

- 這台 WinRM 的 Access Denied 比 F0B6EBED10CB 更深層，可能需要 RDP 進去互動式 debug
- 考慮 WinRM service SDDL 或其他 GPO/安全策略
- v2_local 已驗證可用，WinRM 問題不阻塞部署
