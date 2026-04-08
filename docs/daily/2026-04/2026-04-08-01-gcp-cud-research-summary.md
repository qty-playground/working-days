# GCP CUD 研究總結

## 今天做了什麼

從 GCP Console 的 CUD analysis 頁面研究 CUD 使用狀況，目標是釐清哪些用量沒被覆蓋、花了多少冤枉錢。

## 研究過程

1. 從 GCP Console 截圖觀察 CUD Coverage / Utilization 指標
2. 嘗試用 `gcloud compute commitments list` 查詢，但 CUD 不在 tenmax- 開頭的 project 下，查不到
3. 改用 AppleScript + Chrome JS 自動操作 GCP Console（寫了 `scripts/chrome.sh` 工具）
4. 透過 Download CSV 取得完整資料，用 Python 做 per-project per-SKU 分析
5. 下載 CUD list CSV 取得每筆 CUD 的 start/end date
6. 分析 4/1~4/6 每日 coverage 變化
7. 做了 HTML 時間軸視覺化報告（Plurk 風格垂直時間軸）

## 關鍵發現

- 整體 CUD coverage 只有 45~52%，每天約 $100+ uncovered
- N2 CUD 在 4/3 和 4/7 全數到期（96 vCPU / 384 GB），影響最大
- E2 CUD 上週新買 24 vCPU，但同時 expired 6 vCPU，coverage 仍只有 71.5%
- N1、SSD、AlloyDB、BigQuery、Cloud SQL 都有 eligible usage 但沒有 CUD
- 每月 uncovered 估計約 $2,113

## 產出

- `docs/daily/2026-04/2026-04-07-09-gcp-cud-analysis.md` — 完整分析報告
- `docs/daily/2026-04/2026-04-07-10-applescript-chrome-automation.md` — AppleScript 自動化筆記
- `scripts/chrome.sh` — Chrome 操作工具
- `scripts/screenshot.swift` — 多螢幕截圖工具
- `/tmp/cud_timeline.html` — 視覺化報告（給同事看的版本）

## 下次從這裡開始

- N2 CUD 續買（已確認要買，需決定量）
- E2 CUD 加購評估
- 把 HTML 報告分享給同事討論
