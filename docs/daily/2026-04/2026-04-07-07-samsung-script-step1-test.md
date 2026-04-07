# Samsung Script Step 1 Connection Test

## What we did

Extracted the connection-test logic from the original samsung_monitor_setup.ps1 into a standalone script (step1_test_connection.ps1) and ran it via pt1 on PIC-TW-DOOH-RDP.

## Lessons learned

### Chinese characters break scripts sent via S3 relay
First attempt used Chinese strings (Write-Host with CJK). The script failed to parse on the remote machine (encoding corruption at line 77). Rewrote in English-only, no emoji. Going forward, all scripts intended for pt1 remote execution should be English-only.

### powershell.exe -File produces no output in pt1
Running `powershell.exe -ExecutionPolicy Bypass -File script.ps1` spawns a child process whose stdout is not captured by pt1. Use `& 'path\to\script.ps1'` instead to run in the current session.

### Start-Transcript is essential for pt1 debugging
pt1 wait output only shows what the script explicitly returns. Start-Transcript captures everything (Write-Host, errors, verbose) to a log file on the remote desktop, which can then be read back via pt1.

## Test result

Script: `scripts/step1_test_connection.ps1`
Target: PIC-TW-DOOH-RDP (pt1 client: pic-rdp)

- Viewer file found: TMX000002-211398-xx_viewer.ps1
- Extracted: IP 192.168.0.253, username f0b6ebed0608\OP_Admin, password length 16
- PSSession: created successfully, State Opened
- Get-ComputerInfo: F0B6EBED0608, Windows 10 (build 19041), 64-bit
- Total time: ~6 seconds

Conclusion: viewer parsing + PSSession + Invoke-Command all work through pt1. The reported connection issue did not reproduce with this store host.

## Next steps

- Step 2: Test Set-NetworkIP (static IP on ethernet 2)
- Step 3: Test Send-DisplayCommand (Samsung MDC protocol over TCP 1515)
- Test against other store hosts to see if the connection issue is host-specific
