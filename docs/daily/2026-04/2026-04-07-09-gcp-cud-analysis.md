# GCP CUD Analysis 現況研究

## 背景

研究 GCP Committed Use Discount (CUD) 的使用狀況，釐清哪些用量沒被覆蓋、是誰在花 on-demand 的錢。

## 查詢方法

### 方法一：GCP Console

Billing > CUD analysis 頁面，可切換：
- CUD Coverage / CUD Utilization tab
- Analyze 下拉：Resource based CUDs / Compute Flexible CUD / AlloyDB / BigQuery / Cloud Run / Cloud SQL
- Resource type：All / E2 Cores / E2 Memory / N1 / N2 / Local SSD
- Group by：CUD type / CUD type per region / Service / Region
- Time range：可選 Custom range 指定日期

### 方法二：Download CSV + Python 分析

從 CUD analysis 頁面點 Download CSV，用 Python 分析 CSV。
CSV 欄位包含：Project, Sku Description, Total usage amount, Covered usage amount, Total cost at on-demand rates, Covered cost at on-demand rates, Net cost, Savings 等。
這比 UI 上看到的更細，可以做到 per-project per-SKU 的分析。

### 方法三：gcloud CLI

`gcloud compute commitments list --project=<project> --regions=<region>` 可查詢 CUD 清單。
但只能查單一 project，需要知道 CUD 買在哪個 project 下。
嘗試過 tenmax- 開頭的 9 個 project 都沒有查到 CUD。

### 方法四：AppleScript + Chrome

透過 `osascript` 對 Chrome 執行 JavaScript，可自動操作 GCP Console。
需要先開啟 Chrome 的 View > Developer > Allow JavaScript from Apple Events。
工具放在 `scripts/chrome.sh`，支援 js/jsfile/ss/title/url/body/tab 等指令。

## 觀察數據（2026-04-06 單日，asia-east1）

### 整體指標（All resource types）

| 指標 | 數值 |
|------|------|
| Active CUDs | 2（N2 的 1 筆已 expired）|
| CUD coverage | 77% |
| CUD savings | $27.28/天 |
| Eligible not covered | $25.13/天 |
| Potential savings/month | $368.04 |

### 未覆蓋金額 By SKU（每日）

| Resource | Uncovered/天 | 說明 |
|---|---|---|
| N2 Instance Core | $7.79 | N2 CUD expired，全部回到 on-demand |
| SSD backed Local Storage | $7.28 | 完全沒有 CUD 覆蓋 |
| E2 Custom Instance Core | $7.04 | E2 CUD 量不夠 |
| N2 Instance Ram | $4.36 | N2 CUD expired |
| E2 Custom Instance Ram | $3.56 | E2 CUD 量不夠 |
| E2 Instance Ram | $2.21 | E2 CUD 量不夠 |
| E2 Instance Core | $1.81 | E2 CUD 量不夠 |

### 未覆蓋金額 By Project（每日）

| Project | Uncovered/天 | 約每月 | 主要原因 |
|---|---|---|---|
| bidding-engine-prod | $36.39 | ~$1,091 | N2 CUD expired，跑 N2 的主力 project |
| tenmax-infra | $15.73 | ~$472 | E2 用量最大的 project，94% covered 但基數大 |
| supply-side-platform-prod | $12.21 | ~$366 | N2 CUD expired |
| pic-dooh | $6.56 | ~$197 | E2 coverage 42%，用量不小但 CUD 分配到的少 |
| pchome-ecrmn-beta | $4.24 | ~$127 | beta 環境，可能不值得買 CUD |
| poya-dooh | $4.16 | ~$125 | E2 coverage 42% |
| poya-dooh-beta | $2.85 | ~$86 | beta 環境 |
| retailmax-portal | $2.17 | ~$65 | E2 coverage 43% |
| retailmax-portal-stage | $1.35 | ~$41 | stage 環境 |
| tenmax-office | $1.31 | ~$39 | E2 coverage 45% |
| settv-prod | $1.19 | ~$36 | E2 coverage 43% |
| settv-dev | $1.04 | ~$31 | dev 環境 |
| ec-onemax | $0.81 | ~$24 | E2 coverage 89%，幾乎覆蓋完 |
| mediabox-303708 | $0.74 | ~$22 | E2 coverage 49% |
| tenmax-infra-stage-349201 | $0.43 | ~$13 | stage 環境 |

### E2 Coverage 詳細（每個 project）

E2 整體 coverage 71.5%，on-demand $51.33/天，covered $36.72/天，uncovered $14.61/天。

| Project | Core 用量(hr) | Core Cov% | RAM 用量(GB·h) | RAM Cov% | Uncovered$/天 |
|---|---|---|---|---|---|
| pic-dooh | 157.8 | 42% | 767.7 | 44% | $3.74 |
| tenmax-infra | 792.5 | 94% | 2524.2 | 85% | $2.93 |
| poya-dooh | 107.2 | 42% | 428.7 | 43% | $2.40 |
| retailmax-portal | 52.1 | 43% | 214.4 | 43% | $1.16 |
| retailmax-portal-stage | 34.7 | 43% | 138.8 | 45% | $0.76 |
| poya-dooh-beta | 33.7 | 44% | 138.8 | 45% | $0.74 |
| tenmax-office | 32.7 | 45% | 142.9 | 43% | $0.72 |
| settv-prod | 30.3 | 43% | 125.0 | 43% | $0.68 |
| settv-dev | 26.8 | 42% | 105.7 | 44% | $0.60 |
| mediabox-303708 | 16.9 | 49% | 89.3 | 38% | $0.42 |
| tenmax-infra-stage-349201 | 11.0 | 39% | 44.1 | 40% | $0.26 |
| ec-onemax | 35.2 | 89% | 160.8 | 82% | $0.20 |

大部分 project 的 E2 coverage 只有 40~45%，代表現有 E2 CUD 量只夠覆蓋全部用量的一半不到。

## 名詞釐清

- CUD coverage：實際用量中被 CUD 覆蓋的比例（100% = 所有用量都有折扣）
- CUD utilization：承諾量中被實際消耗的比例（80% = 有 20% 承諾量閒置）
- Un-utilized：付了錢但沒有對應 workload 消耗的承諾量
- Eligible usage：符合購買 CUD 折扣資格的用量，但目前沒有 CUD 覆蓋，正在付 on-demand 價格

## CUD scope 規則

- 目前所有 CUD 的 scope 都是 billing account 層級（頁面上顯示 "Resource-based CUDs scope: Billing account"）
- CSV 裡的 "Subscription Container: Project XXX" 只是記錄在哪個 project 下購買，不代表只給該 project 用
- 整個 billing account 下同 region 同 machine family 的用量都會自動消耗 CUD

## CUD 清單（從 CUD list > Download CSV > Full list 取得）

### Active CUDs

| Name | Family | Cores | Memory | 購買 Project | Term | Start | End |
|---|---|---|---|---|---|---|---|
| commitment-20260402-084919 | E2 | 24 vCPU | — | ScreenMax Beta | 1 year | 2026-04-03 | 2027-04-03 |
| commitment-20240912-032026 | E2 | 2 vCPU | 8 GB | PMAX 3 | 3 years | 2024-09-12 | 2027-09-12 |
| commitment-20250807-065755 | E2 | 60 vCPU | 250 GB | PChome EC RMN Beta | 3 years | 2025-08-08 | 2028-08-08 |

E2 Active 合計：86 vCPU / 258 GB

### 最近 Expired 的 CUDs（4/2~4/7 到期）

| Name | Family | Cores | Memory | 購買 Project | Term | End |
|---|---|---|---|---|---|---|
| commitment-20250402-074214 | N2 | 24 vCPU | 96 GB | Bidding Engine | 1 year | 2026-04-03 |
| commitment-20250402-075503 | N2 | 8 vCPU | 32 GB | Supply Side Platform | 1 year | 2026-04-03 |
| commitment-20250407-025753 | N2 | 20 vCPU | 80 GB | Bidding Engine | 1 year | 2026-04-07 |
| commitment-20250407-merged | N2 | 44 vCPU | 176 GB | Bidding Engine | Custom | 2026-04-07 |
| commitment-20250402-080155 | E2 | 6 vCPU | 24 GB | PIC DOOH | 1 year | 2026-04-03 |
| commitment-20250401-095006 | N1 | 16 vCPU | 87.5 GB | PVMax | 1 year | 2026-04-02 |

Expired 合計：
- N2: 96 vCPU / 384 GB（bidding-engine + supply-side-platform 全部回到 on-demand）
- E2: 6 vCPU / 24 GB（上週新買 24 vCPU 但同時 expired 6 vCPU，淨增 +18 vCPU）
- N1: 16 vCPU / 87.5 GB

### 更早的 Expired CUDs

| Name | Family | Cores | Memory | 購買 Project | Term | End |
|---|---|---|---|---|---|---|
| commitment-1 (2022) | N1 | 17 vCPU | 95 GB | PVMax | 3 years | 2025-03-10 |
| commitment-1 (2020) | N1 | 20 vCPU | 100 GB | PVMax | 1 year | 2021-05-16 |

## 每日 CUD Coverage（4/1~4/6, All resource types, asia-east1）

### 整體

| Date | On-demand | Covered | Uncovered | Coverage |
|---|---|---|---|---|
| 4/1 | $265.17 | $129.34 | $135.83 | 48.8% |
| 4/2 | $233.55 | $119.65 | $113.89 | 51.2% |
| 4/3 | $222.53 | $115.05 | $107.48 | 51.7% |
| 4/4 | $221.75 | $114.79 | $106.96 | 51.8% |
| 4/5 | $222.76 | $115.12 | $107.64 | 51.7% |
| 4/6 | $166.70 | $75.52 | $91.18 | 45.3% |

### By Machine Family

| Date | E2 total | E2 cov% | N2 total | N2 cov% | N1 total | N1 cov% | SSD total | SSD cov% |
|---|---|---|---|---|---|---|---|---|
| 4/1 | $60.44 | 69.3% | $85.54 | 82.0% | $11.87 | 100% | $9.84 | 0% |
| 4/2 | $78.95 | 63.9% | $69.74 | 99.3% | $0.03 | 0% | $9.82 | 0% |
| 4/3 | $69.77 | 79.8% | $69.25 | 85.7% | $0.00 | 0% | $9.83 | 0% |
| 4/4 | $68.99 | 80.3% | $69.25 | 85.7% | $0.00 | 0% | $9.83 | 0% |
| 4/5 | $70.00 | 79.6% | $69.25 | 85.7% | $0.00 | 0% | $9.83 | 0% |
| 4/6 | $51.33 | 71.5% | $50.94 | 76.2% | $0.00 | 0% | $7.28 | 0% |

### 變化分析

- N1: 4/1 $11.87 且 100% covered → 4/2 起 PVMax CUD expired，N1 用量幾乎歸零（可能 VM 也關了）
- N2: 4/1 82% → 4/3 起部分 CUD expired 降到 85.7% → 4/6 再降 76.2%，4/7 大批 expired 後會更低
- E2: 4/1 69.3% → 4/3 新買 24 vCPU 生效跳到 79.8%（同時 PIC DOOH 6 vCPU expired，淨增 18 vCPU）→ 4/6 降回 71.5%
- SSD: 全程 0%，完全沒有 CUD

## 結論與行動項目

1. N2 CUD 全部 expired（96 vCPU / 384 GB）→ 會再買，主要是 bidding-engine-prod 和 supply-side-platform-prod
2. E2 CUD 量不夠 → 上週買了 24 vCPU 但同時 expired 6 vCPU，淨增 +18 vCPU，大部分 project 只有 ~42% coverage
3. Local SSD 有 $7.28/天 uncovered，完全沒有 CUD
4. AlloyDB / BigQuery / Cloud SQL / Cloud Run 都有 eligible usage 但 0 active CUDs

## 待確認

- [ ] N2 CUD 續買量（expired 共 96 vCPU / 384 GB，要買回多少）
- [ ] E2 CUD 要加購多少（目前 86 vCPU 只覆蓋 71.5%，recommendations 建議再加 22 vCPU + 90.4 GB）
- [ ] Local SSD CUD 是否值得買
- [ ] beta/stage 環境是否值得納入 CUD 考量（用量穩定的話可以）
- [ ] AlloyDB / Cloud SQL 的 spend-based CUD 是否要買
- [ ] N1 CUD（PVMax 16 vCPU）是否需要續買
