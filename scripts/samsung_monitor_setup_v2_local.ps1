# Samsung Monitor Setup v2 (Local)
# Runs directly on the store host via pt1 — no PSSession needed
# Flow: Query -> Setup -> Verify

param(
    [switch]$Apply  # default is dry-run (query only), pass -Apply to execute setup
)

$transcriptPath = "$env:USERPROFILE\Desktop\samsung_setup_v2_local_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $transcriptPath
Write-Host "Transcript: $transcriptPath"
Write-Host "Start time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "Mode: $(if ($Apply) { 'LIVE (will apply changes)' } else { 'DRY-RUN (query only)' })"
Write-Host ""

# ============================================================
# Section 1: Query (read-only)
# ============================================================

function Get-LocalNetworkInfo {
    Write-Host "=== Network Adapters ==="
    Get-NetAdapter | Select-Object Name, ifIndex, Status, MacAddress, LinkSpeed | ConvertTo-Json | Write-Host

    Write-Host ""
    Write-Host "=== IPv4 Addresses ==="
    Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin | ConvertTo-Json | Write-Host

    Write-Host ""
    Write-Host "=== Ethernet 2 Detail ==="
    $adapter = Get-NetAdapter | Where-Object { $_.ifIndex -eq 12 -or $_.Name -like "*2*" }
    if ($adapter) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dhcp = Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        @{
            Name = $adapter.Name
            ifIndex = $adapter.ifIndex
            Status = $adapter.Status
            MacAddress = $adapter.MacAddress
            IP = if ($ipConfig) { $ipConfig.IPAddress } else { "N/A" }
            PrefixLength = if ($ipConfig) { $ipConfig.PrefixLength } else { "N/A" }
            DHCP = if ($dhcp) { $dhcp.Dhcp.ToString() } else { "N/A" }
        } | ConvertTo-Json | Write-Host
    } else {
        Write-Host "No adapter matching Ethernet 2 found"
    }
}

function Send-DisplayQuery {
    param(
        [byte[]]$CommandData,
        [string]$Description,
        [string]$ExpectedResponseHex = $null
    )

    Write-Host "  $Description ..."
    $ip = "172.31.255.254"
    $port = 1515
    $output = @{ Sent = ""; Response = ""; Match = "N/A"; Error = "" }

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.SendTimeout = 3000
        $client.ReceiveTimeout = 3000

        $task = $client.ConnectAsync($ip, $port)
        if (-not $task.Wait(5000)) {
            $output.Error = "Connection timeout to ${ip}:${port}"
            Write-Host ($output | ConvertTo-Json)
            return
        }

        $stream = $client.GetStream()
        $stream.Write($CommandData, 0, $CommandData.Length)
        $output.Sent = ($CommandData | ForEach-Object { $_.ToString("X2") }) -join " "

        Start-Sleep -Milliseconds 500

        if ($stream.DataAvailable) {
            $buffer = New-Object byte[] 1024
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -gt 0) {
                $response = $buffer[0..($bytesRead - 1)]
                $output.Response = ($response | ForEach-Object { $_.ToString("X2") }) -join " "
            }
        } else {
            $output.Response = "(no data)"
        }

        if ($ExpectedResponseHex -and $ExpectedResponseHex.Trim().Length -gt 0) {
            if ($output.Response -ieq $ExpectedResponseHex.Trim()) {
                $output.Match = "OK"
            } else {
                $output.Match = "MISMATCH (expected: $ExpectedResponseHex)"
            }
        }

        $stream.Close()
        $client.Close()
    } catch {
        $output.Error = $_.Exception.Message
        try { if ($stream) { $stream.Close() }; if ($client) { $client.Close() } } catch {}
    }

    Write-Host ($output | ConvertTo-Json)
}

function Get-DisplayStatus {
    Write-Host ""
    Write-Host "=== Samsung MDC Queries (TCP 172.31.255.254:1515) ==="

    Send-DisplayQuery `
        -CommandData ([byte[]](0xAA, 0x11, 0x00, 0x00, 0x11)) `
        -Description "Power state" `
        -ExpectedResponseHex "AA FF 00 03 41 11 01 55"

    Send-DisplayQuery `
        -CommandData ([byte[]](0xAA, 0xB5, 0x00, 0x00, 0xB5)) `
        -Description "Network standby" `
        -ExpectedResponseHex "AA FF 00 03 41 B5 01 F9"

    Send-DisplayQuery `
        -CommandData ([byte[]](0xAA, 0x57, 0x00, 0x00, 0x57)) `
        -Description "Brightness" `
        -ExpectedResponseHex "AA FF 00 0A 41 57 06 00 01 50 06 00 00 00 FE"
}

# ============================================================
# Section 2: Setup
# ============================================================

function Set-NetworkIP {
    Write-Host "  Setting Ethernet 2 static IP to 172.31.255.253/30 ..."
    $adapter = Get-NetAdapter | Where-Object { $_.ifIndex -eq 12 -or $_.Name -like "*2*" }
    if (-not $adapter) {
        Write-Host "  ERROR: No Ethernet 2 adapter found"
        return
    }

    $idx = $adapter.ifIndex
    try {
        Set-NetIPInterface -InterfaceIndex $idx -Dhcp Disabled -ErrorAction Stop
        Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -InterfaceIndex $idx -IPAddress "172.31.255.253" -PrefixLength 30 -AddressFamily IPv4 -ErrorAction Stop | Out-Null

        $updated = Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4
        Write-Host "  OK: $($adapter.Name) set to $($updated.IPAddress)/$($updated.PrefixLength)"
    } catch {
        Write-Host "  PowerShell cmdlet failed: $($_.Exception.Message), trying netsh ..."
        try {
            netsh interface ipv4 set address name="$($adapter.Name)" static 172.31.255.253 255.255.255.252 | Out-Null
            Write-Host "  OK (netsh fallback)"
        } catch {
            Write-Host "  ERROR: Both methods failed - $($_.Exception.Message)"
        }
    }
}

function Send-DisplayCommand {
    param(
        [byte[]]$CommandData,
        [string]$Description,
        [string]$ExpectedResponseHex = $null
    )
    # Reuse Send-DisplayQuery — same logic for set commands
    Send-DisplayQuery -CommandData $CommandData -Description $Description -ExpectedResponseHex $ExpectedResponseHex
}

function Invoke-Setup {
    Write-Host ""
    Write-Host "=== Setup: Network IP ==="
    Set-NetworkIP

    Start-Sleep -Seconds 5

    Write-Host ""
    Write-Host "=== Setup: Network Standby ==="
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0xB5, 0x00, 0x01, 0x01, 0xB7)) -Description "Set network standby ON"
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0xB5, 0x00, 0x00, 0xB5)) -Description "Verify network standby" -ExpectedResponseHex "AA FF 00 03 41 B5 01 F9"

    Start-Sleep -Seconds 5

    Write-Host ""
    Write-Host "=== Setup: Brightness ==="
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0x57, 0x00, 0x08, 0x06, 0x00, 0x01, 0x50, 0x06, 0x00, 0x00, 0x00, 0xBC)) -Description "Set brightness to 80"
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0x57, 0x00, 0x00, 0x57)) -Description "Verify brightness" -ExpectedResponseHex "AA FF 00 0A 41 57 06 00 01 50 06 00 00 00 FE"

    Start-Sleep -Seconds 5

    Write-Host ""
    Write-Host "=== Setup: Restart Display ==="
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0x11, 0x00, 0x01, 0x02, 0x14)) -Description "Restart display" -ExpectedResponseHex "AA FF 00 03 41 11 02 56"

    Start-Sleep -Seconds 30

    Write-Host ""
    Write-Host "=== Setup: Power Off ==="
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0x11, 0x00, 0x01, 0x00, 0x12)) -Description "Power OFF display"
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0x11, 0x00, 0x00, 0x11)) -Description "Verify power OFF" -ExpectedResponseHex "AA FF 00 03 41 11 00 54"

    Start-Sleep -Seconds 10

    Write-Host ""
    Write-Host "=== Setup: Power On ==="
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0x11, 0x00, 0x01, 0x01, 0x13)) -Description "Power ON display"
    Start-Sleep -Seconds 10
    Send-DisplayCommand -CommandData ([byte[]](0xAA, 0x11, 0x00, 0x00, 0x11)) -Description "Verify power ON" -ExpectedResponseHex "AA FF 00 03 41 11 01 55"
}

# ============================================================
# Main
# ============================================================

# 1. Query before
Write-Host "=========================================="
Write-Host "  PRE-SETUP STATE"
Write-Host "=========================================="
Get-LocalNetworkInfo
Get-DisplayStatus

# 2. Setup
if ($Apply) {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  APPLYING SETUP"
    Write-Host "=========================================="
    Invoke-Setup

    # 3. Query after
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  POST-SETUP STATE"
    Write-Host "=========================================="
    Get-LocalNetworkInfo
    Get-DisplayStatus
} else {
    Write-Host ""
    Write-Host "DRY-RUN mode: skipping setup. Use -Apply to apply changes."
}

Write-Host ""
Write-Host "End time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Stop-Transcript
