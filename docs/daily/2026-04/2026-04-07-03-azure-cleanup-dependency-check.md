# Azure 資源清理 Step 3-4 依賴檢查完成

## 學到什麼

- VMSS capacity 0 / VM deallocated 的資源不會有 metrics，Step 2 可以跳過
- Traffic Manager 中 sg-be / sg-ssp endpoint 都已 Disabled，domain 實際 resolve 到 GCP IP（34.x.x.x），確認已完成搬遷
- Azure 上無託管 DNS zone，DNS 是在其他地方管理的

## 排查結論

四個 step 全部完成，無依賴風險，可安全刪除：
- 7 個 VMSS（capacity 0）
- 3 台 VM（deallocated）
- 4 個 LB + 5 個 Public IP + 4 個 Managed Disk

額外發現：部分 Traffic Manager profile 的 SG endpoint 全部 Disabled，profile 本身也可能是清理對象。

## 下次從這裡開始

- 整理完整刪除清單（對應 DEV-4644）
- 公告 component owner（對應 DEV-4645）
- 執行刪除（對應 DEV-4646），建議順序：VM/VMSS → LB → Public IP → Disk
- 評估 Traffic Manager profile 是否也要清理
