#!/bin/bash
# Chrome 操作工具：在指定 tab 上執行 JS 或截圖
# 用法:
#   ./scripts/chrome.sh js "document.title"
#   ./scripts/chrome.sh jsfile /tmp/code.js
#   ./scripts/chrome.sh ss [output_path]
#   ./scripts/chrome.sh title
#   ./scripts/chrome.sh url
#   ./scripts/chrome.sh body [char_limit]
#
# 環境變數:
#   CHROME_TAB_MATCH - tab 標題的關鍵字 (預設: CUD)

TAB_MATCH="${CHROME_TAB_MATCH:-CUD}"
CMD="$1"
shift

# 共用：找到目標 tab 並執行 JS 的 AppleScript helper
run_js_on_tab() {
  local js_file="$1"
  python3 - "$TAB_MATCH" "$js_file" << 'PYEOF'
import subprocess, sys

tab_match = sys.argv[1]
js_file = sys.argv[2]

with open(js_file) as f:
    js_code = f.read()

# Escape for AppleScript
js_code = js_code.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")

applescript = f'''
tell application "Google Chrome"
  set wc to count of windows
  repeat with w from 1 to wc
    set tc to count of tabs of window w
    repeat with t from 1 to tc
      if title of tab t of window w contains "{tab_match}" then
        set active tab index of window w to t
        set index of window w to 1
        delay 0.3
        set result to execute active tab of front window javascript "{js_code}"
        return result
      end if
    end repeat
  end repeat
  return "ERROR: tab not found"
end tell
'''

result = subprocess.run(["osascript", "-e", applescript], capture_output=True, text=True)
if result.stdout.strip():
    print(result.stdout.strip())
if result.stderr.strip():
    print(result.stderr.strip(), file=sys.stderr)
    sys.exit(1)
PYEOF
}

# 執行 JS（從字串）
run_js() {
  local tmpfile
  tmpfile=$(mktemp /tmp/chrome_js.XXXXXX.js)
  echo "$1" > "$tmpfile"
  run_js_on_tab "$tmpfile"
  rm -f "$tmpfile"
}

case "$CMD" in
  js)
    run_js "$1"
    ;;
  jsfile)
    run_js_on_tab "$1"
    ;;
  ss)
    OUTPUT="${1:-/tmp/gcp-cud-screenshot.png}"
    ./scripts/screenshot 2 "$OUTPUT"
    ;;
  title)
    run_js "document.title"
    ;;
  url)
    run_js "document.location.href"
    ;;
  body)
    LIMIT="${1:-3000}"
    run_js "document.body.innerText.substring(0, $LIMIT)"
    ;;
  *)
    echo "用法: chrome.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  js <code>         執行 JavaScript"
    echo "  jsfile <path>     從檔案執行 JavaScript"
    echo "  ss [path]         截圖 (Display 2)"
    echo "  title             取得頁面標題"
    echo "  url               取得頁面 URL"
    echo "  body [limit]      取得頁面文字 (預設 3000 字元)"
    echo ""
    echo "環境變數:"
    echo "  CHROME_TAB_MATCH  tab 標題關鍵字 (預設: CUD)"
    ;;
esac
