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

- Project-scoped CUD：優先給該 project 消耗
- Billing account-scoped CUD：整個 billing account 共用
- 當兩者並存時，project-scoped 先消耗
- 如果 project-scoped CUD 用不完，剩餘量會回流給同 billing account 下其他 project

## 結論與行動項目

1. N2 CUD 已 expired → 會再買（bidding-engine-prod + supply-side-platform-prod 每月省 ~$1,457）
2. E2 CUD 量不夠 → 大部分 project 只有 ~42% coverage，需要加購
3. Local SSD 有 $7.28/天 uncovered，完全沒有 CUD
4. AlloyDB / BigQuery / Cloud SQL / Cloud Run 都有 eligible usage 但 0 active CUDs

## 待確認

- [ ] N2 CUD 續買量要多少
- [ ] E2 CUD 要加購多少才合理（目前 recommendations 建議 22 vCPU + 90.4 GB）
- [ ] Local SSD CUD 是否值得買
- [ ] beta/stage 環境是否值得納入 CUD 考量（用量穩定的話可以）
- [ ] AlloyDB / Cloud SQL 的 spend-based CUD 是否要買
