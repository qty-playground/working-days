# Azure 清理相關 Jira Issues

## 背景

DEV-4631 是主 issue，排查完成後接著執行 DEV-4644 → DEV-4645 → DEV-4646。

## Issues 一覽

| Key | Summary | Status | Assignee |
|-----|---------|--------|----------|
| DEV-4631 | 清理 Azure 上面沒在使用但會造成費用的資源 | In Progress | Alan Chan |
| DEV-4644 | 列出相關資源的具體刪除項目 | in backlogs | — |
| DEV-4645 | 公告刪除清單與對應的新資源位置 (GCP) | in backlogs | — |
| DEV-4646 | 執行清除作業 | in backlogs | — |

## 目前進度

排查（DEV-4631）已完成，結論見 2026-04-07-03。
DEV-4644 ~ DEV-4646 尚在 backlog，下一步應先整理清單再公告。

## 執行順序建議

1. DEV-4644：整理完整刪除清單（VMSS × 7、VM × 3、LB × 4、Public IP × 5、Disk × 4，另評估 Traffic Manager profile）
2. DEV-4645：公告給 component owner，等確認
3. DEV-4646：執行刪除，順序 VM/VMSS → LB → Public IP → Disk
