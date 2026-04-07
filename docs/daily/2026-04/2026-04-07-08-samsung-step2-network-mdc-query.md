# Samsung Script Step 2 - Network + MDC Read-only Query

## What we did

Extended step2_check_network.ps1 to include Samsung MDC query commands alongside the network adapter check. All operations are read-only.

Script: `scripts/step2_check_network.ps1`
Target store host: F0B6EBED0608 via PIC-TW-DOOH-RDP

## Network results (same store as step1)

Ethernet 2 ("乙太網路 2"):
- IP: 172.31.255.253/30, Status: Up, 100 Mbps
- Already configured with the target static IP (previous setup run)
- DHCP shows "Enabled" but PrefixOrigin=1 (Manual), a quirk

AlwaysOnVPN interface has IP 192.168.0.253 -- this is how the RDP server reaches the store host via PSSession.

## MDC query results

All three queries got responses (TCP 172.31.255.254:1515 is reachable), but all returned MISMATCH against the original script's expected values.

| Query | Sent | Response | Key byte |
|-------|------|----------|----------|
| Power state | AA 11 00 00 11 | AA FF 00 03 41 11 **00** 54 | 00=OFF |
| Network standby | AA B5 00 00 B5 | AA FF 00 03 **4E** B5 01 06 | 4E=NAK |
| Brightness | AA 57 00 00 57 | AA FF 00 03 **4E** 57 01 A8 | 4E=NAK |

## Lessons learned

### MDC protocol response structure
- Byte 4: 41 (0x41='A') = ACK (success), 4E (0x4E='N') = NAK (failure/unavailable)
- When display is powered off (power query byte 6 = 00), other queries return NAK
- The original script's expected responses assume display is ON, which is why they all mismatch on a powered-off display

### base64 round-trip for transcript retrieval
Using `[Convert]::ToBase64String([System.IO.File]::ReadAllBytes(...))` on remote, then `base64 -d` locally, preserves CJK characters perfectly. This is the reliable way to pull logs via pt1.

### Refactored connection functions
Extracted Get-LatestViewerFile, Get-RemoteConnectionInfo (now takes FilePath param instead of global var), and New-RemoteSession as reusable functions. Send-DisplayQuery is a read-only version of the original Send-DisplayCommand.

## Current progress

| Step | Description | Status |
|------|-------------|--------|
| 1. Connect | viewer parse + PSSession | done |
| 2. Query before set | network info + MDC query | done |
| 3. Set | Set-NetworkIP + MDC set commands | not yet |
| 4. Query after set | re-run step 2 to verify | not yet |

## Next steps

- To properly test MDC set commands, the display needs to be powered ON first
- Consider adding a "power on" step before running the full setup sequence
- Test against other store hosts to check if connection issues are host-specific
