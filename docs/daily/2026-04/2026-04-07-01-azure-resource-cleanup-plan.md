# Azure 殘留資源清理排查計畫

## 背景

DEV-4631：Azure 上有殘留資源持續產生費用，需排查後移除。
已建立 my-tasks issue: https://github.com/qty-work-in-progress/tasks/issues/6

## 已知待清理資源（來自 Jira）

VMSS（約 2400 NTD/month）：
- tenmax-sg-bidder-vmss
- tenmax-sg-bidder-stage-vmss
- tenmax-sg-ssp-ap-server-vmss
- tenmax-sg-ssp-ap-server-vmss-stage

VM（約 30 NTD/month）：
- tenmax-sg-bidder-redis1（BE 已確認可移除）
- tenmax-gitlab
- tenmax-sg-ssp-web200

## 排查步驟

1. 確認資源目前狀態（instance count、running/deallocated）
2. 查 metrics 近 30 天（CPU、Network In/Out）— 沒流量 = 高機率沒在用
3. 查關聯資源（NSG、Load Balancer、Traffic Manager）— 刪除前需先解除
4. 確認無其他依賴（DNS 指向、其他服務 config 的 hardcode IP/hostname）

工具：az CLI
