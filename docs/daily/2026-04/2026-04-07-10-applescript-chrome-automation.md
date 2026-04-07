# AppleScript + Chrome 自動化操作 GCP Console

## 背景

研究 GCP CUD 時，需要反覆在 GCP Console 上操作（切換下拉選單、截圖、下載 CSV）。
手動截圖再貼過來太慢，於是用 AppleScript 對 Chrome 執行 JavaScript 來自動化。

## 前置條件

Chrome 需開啟：View > Developer > Allow JavaScript from Apple Events

## 工具

### scripts/screenshot.swift

用 Swift 寫的截圖工具，支援多螢幕。

```
./scripts/screenshot           # 列出所有 display
./scripts/screenshot 2 out.png # 截指定 display
```

編譯：`swiftc scripts/screenshot.swift -o scripts/screenshot`

重點 API：
- `CGGetActiveDisplayList` 取得螢幕列表
- `CGDisplayCreateImage` 截圖
- `CGImageDestinationCreateWithURL` 存 PNG

### scripts/chrome.sh

對 Chrome 指定 tab 執行 JS 的 shell script。

```bash
./scripts/chrome.sh js "document.title"          # 執行 JS
./scripts/chrome.sh jsfile /tmp/code.js           # 從檔案執行 JS
./scripts/chrome.sh ss                            # 截圖 Display 2
./scripts/chrome.sh title                         # 取得頁面標題
./scripts/chrome.sh body 3000                     # 讀頁面文字
```

透過環境變數 `CHROME_TAB_MATCH` 指定要操作的 tab（預設搜尋標題含 "CUD"）：
```bash
CHROME_TAB_MATCH="Billing" ./scripts/chrome.sh body 3000
```

## 踩過的坑

### 1. AppleScript 引號跳脫地獄

直接在 shell 裡用 `osascript -e` 嵌 JS，引號巢狀很容易壞。
解法：把 JS 寫到暫存檔，用 Python 讀檔後做 escape 再傳給 osascript。

### 2. front window 不一定是你要的

Chrome 有多個 window 時，`front window` 可能是 Slack 而不是 GCP。
解法：遍歷所有 window 和 tab，用標題關鍵字找到目標 tab。

### 3. Chrome tab title 會變

導航到新頁面後 tab title 改變，原本的 `CHROME_TAB_MATCH` 就找不到了。
解法：用比較通用的關鍵字（如 "Billing"）而不是太具體的（如 "CUD"）。

### 4. GCP Console 的 DOM 操作

- GCP 用 `cfc-select` 自訂元件，不是原生 `<select>`，需要用 `.click()` 打開再找 `[role="option"]`
- 選項的 click 需要 dispatch 完整的 mouse event sequence（mousedown → mouseup → click）才會生效
- 頁面切換後需要 `setTimeout` 或 `sleep` 等待載入
- 日期輸入框需要用 `nativeInputValueSetter` 繞過 React/Angular 的 controlled input

### 5. 表格資料讀不到

CUD list 頁面的表格用了 virtual rendering，某些欄位（State, Start date, End date）在 DOM 上是空的。
解法：用 Download CSV (Full list) 取得完整資料，比爬 DOM 可靠得多。

## 心得

AppleScript + Chrome JS 這套組合可以快速做到「半自動」操作瀏覽器，適合：
- 需要登入驗證的頁面（不用處理 auth）
- 臨時性的資料抓取
- 配合截圖工具做視覺確認

但不適合複雜的自動化流程，因為 DOM 結構不穩定、timing 難控制。
如果要做 production-level 的自動化，用 Playwright 或 Puppeteer 會更好。
