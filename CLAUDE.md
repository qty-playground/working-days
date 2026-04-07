# Working Days - 工作記錄專用

## 重要規則

### 簡單方案優先
有多種實作方式時，選最簡單、moving parts 最少的方案。不確定使用者想要哪種做法時，先用 2 句話描述方案再動手，不要直接蓋複雜版本。

### CLI 指令驗證
執行不熟悉或本次對話中沒用過的 CLI flag 前，先跑 `<command> --help` 確認該 flag 存在。不要憑記憶猜測 flag 名稱。

### 學到新東西就記日記
工作過程中，只要學到新知識、發現重要資訊、做出決策，就立即記錄到 docs/daily/ 目錄：
- 目錄按月份分：`docs/daily/yyyy-mm/`
- 檔名格式：`yyyy-mm-dd-<number>-<subject>.md`
- 完整路徑範例：`docs/daily/2026-03/2026-03-14-01-add-claude-md-rules.md`
- 同一天有多個記錄時，使用遞增的編號（01, 02, 03...）
- 這些日記用於日後回顧與追蹤工作脈絡

不要等到「階段性完成」才記錄，學到了就寫下來。
日記中若有明確的「下次從這裡開始」或「下次想做」的內容，同步存入記憶，讓下次開工時能回想起來。
注意：這是 public repo，日記內容不可包含 sensitive data（API keys、tokens、帳號密碼、內部 URL 等）。

### 常用縮寫
- `ddd` → 工作一個段落了，寫 daily log
- `gg` → 用 `git grep` 快速查詢

### 規則管理
- 發現重要規則時，詢問是否加入 CLAUDE.md
- 學到新知識時，立即記錄日誌到 docs/

## 工作環境
- 專案內有 venv 時，優先使用專案的 venv
- 永遠以 project root 作為工作目錄

## Retrospective
- 工作過程中適時將學到的重點整理進 CLAUDE.md
- 修改 CLAUDE.md 前須獲得使用者同意
- 發現重要規則時，詢問是否加入 CLAUDE.md