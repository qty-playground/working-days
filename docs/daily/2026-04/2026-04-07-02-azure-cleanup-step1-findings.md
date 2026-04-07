# Azure 資源清理 Step 1 查詢結果

## 學到什麼

用 `az cli` 查 VMSS/VM 狀態時，除了看主資源本身，還要查關聯的付費資源：
- Public IP（Static Standard SKU 閒置也收費）
- Load Balancer（Standard SKU 有基本費）
- Managed Disk（deallocated VM 的 disk state=Reserved，持續收儲存費）

Jira 上估的費用（VMSS 2400 + VM 30 NTD/month）可能低估了，因為沒算到 LB 和 Public IP 的費用。

## 查詢結果摘要

VMSS capacity 0 共 7 個（Jira 列 4 個，另外發現 3 個 spark 相關）。
VM deallocated 共 3 個。
關聯資源：4 個 LB、5 個 Public IP、4 個 Managed Disk。

詳細資料記錄在 my-tasks issue #6 的 comments 中。

## 用到的 az CLI 指令

全部是 read-only 查詢：
- `az vmss list --query '...'` — 列出 VMSS 及 capacity
- `az vm get-instance-view` — 查 VM power state
- `az network public-ip list -g <rg>` — 查 Public IP 配置
- `az network lb list -g <rg>` — 查 Load Balancer
- `az disk list -g <rg>` — 查 Managed Disk

## 下一步

- Step 2: 查 metrics 確認長期閒置（但 capacity 0 / deallocated 已經很明確）
- Step 3-4: 查 Traffic Manager、DNS 確認刪除前無依賴
- 整理完整刪除清單後公告 component owner（DEV-4645）
