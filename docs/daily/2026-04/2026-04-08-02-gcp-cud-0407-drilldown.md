# GCP CUD 4/7 全日 Drilldown 分析

## 背景

N2 CUD 在 4/3 和 4/7 全數到期後，以 4/7 單日為基準，完整盤點所有 resource type 和 service 的 CUD 缺額。

## 資料來源

- GCP Console CUD analysis 頁面，日期 4/7，region asia-east1
- 透過 AppleScript + Chrome 自動化切換各下拉選項收集
- Download CSV 做 per-project per-SKU 分析

## Analyze 選項總覽

| Analyze | Active CUDs | On-demand/day | Uncovered/day | 建議 |
|---------|-------------|---------------|---------------|------|
| Resource based + Flexible | 3 (E2 only) | $49.62 | $34.71 | 主戰場 |
| AlloyDB | 0 | $2.38 | $2.38 | 建議評估 spend-based CUD |
| BigQuery | 0 | (無數據) | — | 略 |
| Cloud Run | 0 | $8.50 | $8.50 | 無 CUD recommendation |
| Cloud SQL | 0 | $8.22 | $8.22 | 建議評估 spend-based CUD |

## Resource Type 缺額明細（Resource based + Flexible, 4/7 單日）

### Usage 缺額（不含 CUD 承諾費）

| SKU | Total Usage | Uncov Usage | Unit | Uncov$/day | Coverage |
|-----|------------|-------------|------|------------|----------|
| N2 Instance Core | 342.6 | 342.6 | hour | $12.54 | 0% |
| N2 Instance Ram | 1370.4 | 1370.4 | GiB·hr | $6.72 | 0% |
| E2 Instance Core | 455.6 | 163.4 | hour | $4.13 | 64.1% |
| E2 Custom Instance Core | 263.9 | 138.6 | hour | $3.67 | 47.5% |
| E2 Instance Ram | 1875.2 | 963.7 | GiB·hr | $3.26 | 48.6% |
| Local SSD | 34.3 | 34.3 | GiB·month | $2.74 | 0% |
| E2 Custom Instance Ram | 778.4 | 460.4 | GiB·hr | $1.64 | 40.8% |

Usage 小計: on-demand $49.62/day, uncovered $34.71/day (~$1,041/month)

### CUD 承諾費

現有 CUD 承諾費: $19.72/day（3 筆 active E2 CUD）

### 整體

4/7 actual cost = usage uncovered $34.71 + CUD commitment $19.72 = $54.43/day
如果 CUD 完美覆蓋所有 usage，理論上可以更低。

## Per Project 缺額排名（Usage only, 4/7 單日）

| Project | Uncov$/day | N2 | E2 | SSD | Coverage | ~月缺額 |
|---------|-----------|-----|-----|-----|----------|---------|
| bidding-engine-prod | $16.02 | $14.09 | $0.00 | $1.92 | 0% | $481 |
| supply-side-platform-prod | $5.99 | $5.17 | $0.00 | $0.82 | 0% | $180 |
| pchome-ecrmn-beta | $4.88 | $0.00 | $4.88 | $0.00 | 37.3% | $147 |
| tenmax-infra | $2.86 | $0.00 | $2.86 | $0.00 | 75.1% | $86 |
| pic-dooh | $1.53 | $0.00 | $1.53 | $0.00 | 38.3% | $46 |
| poya-dooh | $0.94 | $0.00 | $0.94 | $0.00 | 38.5% | $28 |
| retailmax-portal | $0.47 | $0.00 | $0.47 | $0.00 | 38.5% | $14 |
| 其他 7 個 project | $1.86 | $0.00 | $1.86 | $0.00 | ~38% | $56 |

## 缺額明細 Top 10（Project × SKU）

| Project | SKU | Usage | Uncov$/day |
|---------|-----|-------|-----------|
| bidding-engine-prod | N2 Core | 250.7 hr | $9.17 |
| bidding-engine-prod | N2 Ram | 1002.7 GiB·hr | $4.92 |
| tenmax-infra | E2 Custom Core | 250.7 hr | $3.52 |
| supply-side-platform-prod | N2 Core | 91.9 hr | $3.36 |
| pchome-ecrmn-beta | E2 Core | 200.9 hr | $3.06 |
| SSD (bidding-engine) | Local SSD | 24.0 GiB·month | $1.92 |
| pchome-ecrmn-beta | E2 Ram | 803.5 GiB·hr | $1.82 |
| supply-side-platform-prod | N2 Ram | 367.7 GiB·hr | $1.80 |
| tenmax-infra | E2 Custom Ram | 712.4 GiB·hr | $1.50 |
| tenmax-infra | E2 Core (1yr commitment cost) | — | $1.08 |

## 關鍵發現

1. N2 CUD 全數到期，100% uncovered，每日缺 $19.26（Core $12.54 + Ram $6.72），月損 ~$578
   - bidding-engine-prod 佔 74%（$14.09/day）
   - supply-side-platform-prod 佔 27%（$5.17/day）

2. E2 CUD 覆蓋不足，整體約 50%，每日缺 $12.71，月損 ~$381
   - pchome-ecrmn-beta 是 E2 最大缺口（$4.88/day），只有 37% coverage
   - tenmax-infra 基數大但 coverage 75%，缺口 $2.86/day
   - E2 Instance Core 64% covered vs E2 Custom Instance Core 僅 47%

3. Local SSD 完全沒有 CUD，$2.74/day（月 ~$82），全在 bidding-engine + ssp

4. E2 CUD savings 是負的（-$0.03），代表 E2 Core 的承諾費略高於覆蓋量的 on-demand 價。
   但 E2 Memory 有 $0.65 savings（11% discount），合計 E2 仍是正的。

5. 非 Compute 的 eligible usage：
   - Cloud SQL: $8.22/day，GCP 建議可省 $205.75/month
   - Cloud Run: $8.50/day，無 recommendation
   - AlloyDB: $2.38/day，GCP 建議可省 $121.52/month

## N2 CUD 續買建議

之前 expired 的 N2 CUD 合計 96 vCPU / 384 GB。
4/7 實際 N2 usage: 342.6 vCPU·hr / 1370.4 GiB·hr → 平均 14.275 vCPU + 57.1 GB per hour。

等等，這數字比 expired 量小很多。可能是因為 VMSS 已經縮小了？需要確認 N2 的 actual instance count 是否有變化。

## GCP Recommendations 頁面（截至 4/5 更新）

| 省多少/月 | Service | 建議 | 類型 | Region | 建議量 |
|-----------|---------|------|------|--------|--------|
| $368.04 | Compute Engine | 買 3 年 Compute Flexible CUD | Spend-based | All regions | $0.81/hr |
| $205.75 | Cloud SQL | 買 3 年 Cloud SQL CUD | Spend-based | asia-east1 | $0.26/hr |
| $168.37 | Compute Engine | 加買 N2 Cores (3 年) | Resource-based | asia-east1 | 22 vCPU |
| $121.52 | AlloyDB | 買 3 年 AlloyDB CUD | Spend-based | All regions | $0.16/hr |
| $91.62 | Compute Engine | 加買 N2 Memory (3 年) | Resource-based | asia-east1 | 90.4 GB |
| $71.88 | Compute Engine | 買 N1 Cores (3 年) | Resource-based | asia-east1 | 13 vCPU |
| $32.50 | Compute Engine | 買 N1 Memory (3 年) | Resource-based | asia-east1 | 43.875 GB |

合計潛在節省: $837.95/month

注意：Recommendations 是 4/5 算的，N2 CUD 4/7 才全部到期，N2 建議量（22 vCPU + 90.4 GB）可能偏低。

其他觀察：
- Compute Flexible CUD（$368.04）是 spend-based 跨 service 通用，折扣率比 resource-based 低。如果 N2/E2 用量穩定，resource-based 比較划算
- 頁面上 CUD recommendations threshold 設為 90% of total usage
- Last month's realized CUD savings: $1,517.62

## 分析方法筆記

1. 用 AppleScript + Chrome（scripts/chrome.sh）自動切換 GCP Console 的下拉選項
2. CHROME_TAB_MATCH 環境變數控制要操作的 tab（頁面導航後標題會變，需要調整 match keyword）
3. Analyze 下拉有 7 個選項，Resource type 有 8 個選項
4. 頁面上的表格用 virtual rendering，直接爬 DOM 不可靠，用 Download CSV 取 per-project per-SKU 完整數據
5. CSV 裡有兩類 SKU 要分開看：
   - Usage SKU（如 N2 Instance Core）→ 實際資源用量
   - Commitment SKU（如 Commitment v1: E2 Cpu）→ CUD 承諾費用帳單項目
   混在一起算 uncovered 會失真，要分開計算
6. 當天的 billing data 通常要隔天才完整（4/8 查 4/8 無資料）

## 下次從這裡開始

- 看 4/8 完整數據，跟 4/7 比較（確認趨勢穩定）
- 確認 N2 actual instance 數量（是否已縮減）— recommendations 建議 22 vCPU 但 expired 量是 96 vCPU，差距大
- 等 recommendations 更新（反映 4/7 N2 全部到期後的建議量）
- Cloud SQL / AlloyDB spend-based CUD 評估
- 把分析報告分享給同事討論續買決策
