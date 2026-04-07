# Samsung v2 Live Test - Access Denied on PIC2400160

## What happened

Dry-run v2 on a new store host PIC2400160 (中航), PSSession failed with "Access is denied".

- Viewer file: PIC2400160-170978-中航_viewer.ps1
- Target: 192.168.1.116, f0b6ebed0542\OP_Admin
- WinRM port 5985: reachable (Test-NetConnection = true)
- ICMP: not enabled on store hosts (don't use ping to test)

## Investigation

Downloaded _admin.ps1 from the same store — same IP, same credentials, uses Invoke-Command (WinRM). User confirmed admin script can connect.

Re-downloaded viewer twice, MD5 identical — not a stale credential issue.

Installed pt1 client directly on the target machine (F0B6EBED0542) and checked WinRM config:

| Setting | Value |
|---------|-------|
| Service AllowRemoteAccess | true |
| Service Auth Negotiate | true |
| Service Auth Kerberos | true |
| Service AllowUnencrypted | false |
| Listener | HTTP port 5985, bound to 192.168.1.116 |
| RDP Server TrustedHosts | * (all allowed) |

Everything looks correct. Access Denied root cause still unknown.

## Possible remaining causes

- OP_Admin password special chars (`eq,(F@3U9Mkk2H5T`) causing escaping issues in pt1 relay
- pt1 agent running as different user context than interactive PowerShell
- WinRM service needing restart after config change
- Firewall rule allowing 5985 but WinRM auth failing at a different layer

## Lessons learned

- ICMP is disabled on store hosts, use `Test-NetConnection -Port 5985` instead of ping
- admin.ps1 and viewer.ps1 are different download types from the management portal — admin uses Invoke-Command (WinRM), viewer uses PsExec + mstsc (RDP shadow)
- v2 script's Get-LatestViewerFile filter `*_viewer.ps1` won't match browser duplicate names like `(1).ps1`

## Next steps

- Test PSSession from RDP Server interactively (not through pt1) to isolate if it's a pt1 relay issue
- Check if the password special chars need different escaping in pt1 context
- Try from pic-rdp with explicit credential construction matching admin.ps1's approach
