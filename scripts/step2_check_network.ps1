# Step 2: Check current network and display state on remote host
# Purpose: Read-only inspection of network config + Samsung MDC query

$transcriptPath = "$env:USERPROFILE\Desktop\step2_check_network_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $transcriptPath
Write-Host "Transcript: $transcriptPath"
Write-Host "Start time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# --- Reuse Step 1: viewer parsing + PSSession ---

function Get-LatestViewerFile {
    $dir = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    $file = Get-ChildItem -Path $dir -Filter "*_viewer.ps1" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $file) {
        Write-Host "ERROR: No *_viewer.ps1 found in $dir"
        return $null
    }
    Write-Host "Viewer file: $($file.Name)"
    return $file
}

function Get-RemoteConnectionInfo {
    param([string]$FilePath)
    $content = Get-Content $FilePath -Raw

    $info = @{}
    if ($content -match "\\\\([\d\.]+)") { $info.RemoteHost = $matches[1] } else { Write-Host "ERROR: No IP found"; return $null }
    if ($content -match "-u\s+([\w\\]+)") { $info.Username = $matches[1] } else { Write-Host "ERROR: No username found"; return $null }
    if ($content -match "-p\s+'([^']+)'") { $info.Password = $matches[1] } else { Write-Host "ERROR: No password found"; return $null }

    Write-Host "Remote host: $($info.RemoteHost), User: $($info.Username)"
    $secPass = $info.Password | ConvertTo-SecureString -AsPlainText -Force
    $info.Credential = New-Object System.Management.Automation.PSCredential ($info.Username, $secPass)
    return $info
}

function New-RemoteSession {
    param($ConnectionInfo)
    Write-Host "Creating PSSession to $($ConnectionInfo.RemoteHost) ..."
    try {
        $session = New-PSSession -ComputerName $ConnectionInfo.RemoteHost -Credential $ConnectionInfo.Credential -ErrorAction Stop
        Write-Host "PSSession created (ID: $($session.Id), State: $($session.State))"
        return $session
    } catch {
        Write-Host "ERROR: PSSession failed - $($_.Exception.Message)"
        return $null
    }
}

# --- Step 2: Read-only network check ---

function Get-RemoteNetworkInfo {
    param([System.Management.Automation.Runspaces.PSSession]$Session)

    Write-Host ""
    Write-Host "=== Network Adapters ==="
    $adapters = Invoke-Command -Session $Session -ScriptBlock {
        Get-NetAdapter | Select-Object Name, ifIndex, Status, MacAddress, LinkSpeed | ConvertTo-Json
    }
    Write-Host $adapters

    Write-Host ""
    Write-Host "=== IPv4 Addresses ==="
    $ipAddresses = Invoke-Command -Session $Session -ScriptBlock {
        Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin | ConvertTo-Json
    }
    Write-Host $ipAddresses

    Write-Host ""
    Write-Host "=== Ethernet 2 Detail ==="
    $eth2 = Invoke-Command -Session $Session -ScriptBlock {
        $adapter = Get-NetAdapter | Where-Object { $_.Name -like "*2*" -or $_.Name -like "*Ethernet 2*" }
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
            } | ConvertTo-Json
        } else {
            "No adapter matching 'Ethernet 2' found"
        }
    }
    Write-Host $eth2
}

# --- MDC read-only query ---

function Send-DisplayQuery {
    param(
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [byte[]]$CommandData,
        [string]$Description,
        [string]$ExpectedResponseHex = $null
    )

    Write-Host "  $Description ..."
    $result = Invoke-Command -Session $Session -ScriptBlock {
        param($CmdData, $ExpectedHex)

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
                return $output | ConvertTo-Json
            }

            $stream = $client.GetStream()
            $stream.Write($CmdData, 0, $CmdData.Length)
            $output.Sent = ($CmdData | ForEach-Object { $_.ToString("X2") }) -join " "

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

            if ($ExpectedHex -and $ExpectedHex.Trim().Length -gt 0) {
                if ($output.Response -ieq $ExpectedHex.Trim()) {
                    $output.Match = "OK"
                } else {
                    $output.Match = "MISMATCH (expected: $ExpectedHex)"
                }
            }

            $stream.Close()
            $client.Close()
        } catch {
            $output.Error = $_.Exception.Message
            try { if ($stream) { $stream.Close() }; if ($client) { $client.Close() } } catch {}
        }

        return $output | ConvertTo-Json
    } -ArgumentList $CommandData, $ExpectedResponseHex

    Write-Host $result
}

function Get-DisplayStatus {
    param([System.Management.Automation.Runspaces.PSSession]$Session)

    Write-Host ""
    Write-Host "=== Samsung MDC Queries (TCP 172.31.255.254:1515) ==="

    # Query power state
    Send-DisplayQuery -Session $Session `
        -CommandData ([byte[]](0xAA, 0x11, 0x00, 0x00, 0x11)) `
        -Description "Power state" `
        -ExpectedResponseHex "AA FF 00 03 41 11 01 55"

    # Query network standby
    Send-DisplayQuery -Session $Session `
        -CommandData ([byte[]](0xAA, 0xB5, 0x00, 0x00, 0xB5)) `
        -Description "Network standby" `
        -ExpectedResponseHex "AA FF 00 03 41 B5 01 F9"

    # Query brightness
    Send-DisplayQuery -Session $Session `
        -CommandData ([byte[]](0xAA, 0x57, 0x00, 0x00, 0x57)) `
        -Description "Brightness" `
        -ExpectedResponseHex "AA FF 00 0A 41 57 06 00 01 50 06 00 00 00 FE"
}

# --- Main ---

$viewerFile = Get-LatestViewerFile
if (-not $viewerFile) { Stop-Transcript; exit 1 }

$connInfo = Get-RemoteConnectionInfo -FilePath $viewerFile.FullName
if (-not $connInfo) { Stop-Transcript; exit 1 }

$session = New-RemoteSession -ConnectionInfo $connInfo
if (-not $session) { Stop-Transcript; exit 1 }

Get-RemoteNetworkInfo -Session $session
Get-DisplayStatus -Session $session

# Cleanup
Remove-PSSession $session -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Session closed"
Write-Host "End time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Stop-Transcript
