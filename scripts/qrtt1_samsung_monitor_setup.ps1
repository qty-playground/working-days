# 動態尋找最新的 *_viewer.ps1 檔案
function Get-LatestViewerFile {
    $viewerDirectory = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    $latestFile = Get-ChildItem -Path $viewerDirectory -Filter "*_viewer.ps1" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object { $_.FullName }

    if (-not $latestFile) {
        Write-Error "未找到任何 *_viewer.ps1 檔案，請確認檔案是否存在於 $viewerDirectory"
        return $null
    }

    return $latestFile
}

# 協助函數: 將前綴長度轉換為子網掩碼 (全域函數)
function Convert-PrefixToMask {
    param (
        [int]$PrefixLength
    )
    
    $bitString = ('1' * $PrefixLength).PadRight(32, '0')
    $octets = @()
    
    for ($i = 0; $i -lt 32; $i += 8) {
        $octet = [Convert]::ToInt32($bitString.Substring($i, 8), 2)
        $octets += $octet
    }
    
    return $octets -join '.'
}

# 從 viewer.ps1 提取遠端連線資訊的函數
function Get-RemoteConnectionInfo {
    # 檢查檔案是否存在
    if (-not (Test-Path $viewerFilePath)) {
        Write-Error "檔案未找到: $viewerFilePath"
        return $null
    }

    # 讀取檔案內容
    $viewerContent = Get-Content $viewerFilePath -Raw

    # 定義正則表達式模式
    $ipPattern = "\\\\([\d\.]+)"
    $usernamePattern = "-u\s+([\w\\]+)"
    $passwordPattern = "-p\s+'([^']+)'"

    $connectionInfo = @{}

    # 抽取 IP 地址
    if ($viewerContent -match $ipPattern) {
        $connectionInfo.RemoteHost = $matches[1]
        Write-Host "已提取 IP: $($connectionInfo.RemoteHost)"
    } else {
        Write-Error "無法提取 IP 地址。"
        return $null
    }

    # 抽取使用者名稱
    if ($viewerContent -match $usernamePattern) {
        $connectionInfo.Username = $matches[1]
        Write-Host "已提取使用者名稱: $($connectionInfo.Username)"
    } else {
        Write-Error "無法提取使用者名稱。"
        return $null
    }

    # 抽取密碼
    if ($viewerContent -match $passwordPattern) {
        $connectionInfo.Password = $matches[1]
        Write-Host "已提取密碼"
    } else {
        Write-Error "無法提取密碼。"
        return $null
    }

    # 創建憑證
    $securePassword = $connectionInfo.Password | ConvertTo-SecureString -AsPlainText -Force
    $connectionInfo.Credential = New-Object System.Management.Automation.PSCredential ($connectionInfo.Username, $securePassword)

    return $connectionInfo
}


# 功能2: 設定主機乙太網路2私有IP
function Set-NetworkIP {
    param (
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    Write-Host "正在設定乙太網路2的私有IP..."
    
    $scriptBlock = {
        Write-Host "正在設定乙太網路2的 IP 配置..."

        # 設定指定介面的 IP 地址和子網掩碼
        $interfaceName = "乙太網路 2"
        $ipAddress = "172.31.255.253"
        $prefixLength = 30  # 子網掩碼 255.255.255.252 對應的前綴長度是 30

        # 檢查介面是否存在
        $interface = Get-NetAdapter | Where-Object { $_.Name -eq $interfaceName }
        
        if ($interface) {
            $interfaceIndex = $interface.ifIndex
            Write-Host "找到網路介面 '$interfaceName'，索引為: $interfaceIndex"
            
            try {
                # 首先停用 DHCP
                Write-Host "正在停用 DHCP..."
                Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled
                
                # 移除現有的 IP 配置
                Write-Host "正在移除現有 IP 配置..."
                Get-NetIPAddress -InterfaceIndex $interfaceIndex -ErrorAction SilentlyContinue | 
                    Where-Object { $_.AddressFamily -eq "IPv4" } | 
                    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
                
                # 設定新的 IP 地址
                Write-Host "正在設定新的靜態 IP..."
                $result = New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress $ipAddress -PrefixLength $prefixLength -AddressFamily IPv4
                
                Write-Host "成功設定 $interfaceName 的 IP 地址為 $ipAddress，子網掩碼為 255.255.255.252"
                
                # 顯示更新後的配置
                $updatedConfig = Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4
                Write-Host "更新後的 IP 配置:"
                Write-Host "  介面: $interfaceName (索引: $interfaceIndex)"
                Write-Host "  IP: $($updatedConfig.IPAddress)"
                Write-Host "  前綴長度: $($updatedConfig.PrefixLength)"
                Write-Host "  DHCP 狀態: 已停用"
            }
            catch {
                Write-Host "設定 IP 時發生錯誤: $_"
                Write-Host "錯誤詳情: $($_.Exception.Message)"
                Write-Host "嘗試使用替代方法..."
                
                # 使用 netsh 命令作為備選方案
                try {
                    # 使用 netsh 停用 DHCP 並設定靜態 IP
                    $netmask = "255.255.255.252"
                    $cmd = "netsh interface ipv4 set address name=`"$interfaceName`" static $ipAddress $netmask"
                    Write-Host "執行: $cmd"
                    Invoke-Expression $cmd
                    Write-Host "已使用 netsh 命令成功設定 IP"
                }
                catch {
                    Write-Host "使用 netsh 設定 IP 時也發生錯誤: $_"
                }
            }
        }
        else {
            Write-Host "錯誤: 找不到名為 '$interfaceName' 的網路介面。"
            Write-Host "可用的網路介面有:"
            Get-NetAdapter | ForEach-Object {
                Write-Host "  名稱: $($_.Name), 索引: $($_.ifIndex), 狀態: $($_.Status)"
            }
        }
    }
    
    Invoke-Command -Session $Session -ScriptBlock $scriptBlock
} 

 # 功能3: 檢查主機與螢幕是否連線
function Test-DisplayConnection {
    param (
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    Write-Host "正在檢查主機與螢幕的連線..."
    
    $convertFuncDef = ${function:Convert-PrefixToMask}.ToString()
    
    $scriptBlock = {
        param($convertFunc)
        
        # 載入轉換函數到遠端會話
        $ExecutionContext.InvokeCommand.NewScriptBlock($convertFunc) | Set-Item -Path Function:Convert-PrefixToMask
        
        $displayIP = "172.31.255.254"
        Write-Host "正在測試與螢幕($displayIP)的連線..."
        
        # 使用ping測試連線
        $pingResult = Test-Connection -ComputerName $displayIP -Count 4 -Quiet
        
        if ($pingResult) {
            Write-Host "成功: 螢幕連線正常，可以通過ping到達。"
            Write-Host "正在顯示詳細的ping測試結果:"
            $detailedResult = Test-Connection -ComputerName $displayIP -Count 4
            $detailedResult | Format-Table -Property Address, IPV4Address, ResponseTime
        } else {
            Write-Host "失敗: 無法連接到螢幕。請檢查網路連線和螢幕IP設定。"
            
            # 顯示網路診斷資訊
            Write-Host "`n正在嘗試診斷連線問題..."
            Write-Host "本機乙太網路2介面配置:"
            $eth2 = Get-NetAdapter -Name "乙太網路 2" -ErrorAction SilentlyContinue
            if ($eth2) {
                $ipConfig = Get-NetIPAddress -InterfaceIndex $eth2.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                if ($ipConfig) {
                    Write-Host "  介面狀態: $($eth2.Status)"
                    Write-Host "  本機IP: $($ipConfig.IPAddress)"
                    Write-Host "  子網掩碼前綴: $($ipConfig.PrefixLength)"
                    Write-Host "  子網掩碼: $(Convert-PrefixToMask $ipConfig.PrefixLength)"
                } else {
                    Write-Host "  未設定IPv4地址"
                }
            } else {
                Write-Host "  找不到乙太網路2介面"
            }
            
            # 嘗試獲取ARP資訊
            Write-Host "`n顯示ARP表資訊:"
            try {
                $arpInfo = arp -a | Where-Object { $_ -like "*$displayIP*" }
                if ($arpInfo) {
                    Write-Host $arpInfo
                } else {
                    Write-Host "ARP表中未找到螢幕的MAC地址，可能表示從未成功通訊過。"
                }
            } catch {
                Write-Host "無法獲取ARP資訊: $_"
            }
        }
    }
    
    Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $convertFuncDef
} 

function Send-DisplayCommand {
    param (
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [byte[]]$CommandData,
        [string]$CommandDescription,
        [string]$ExpectedResponseHex = $null  # 可選參數，用來指定預期回應
    )
    
    Write-Host "執行中：$CommandDescription..."

    $scriptBlock = {
        param($CmdData, $CmdDesc, $ExpectedHex)

        $ip = "172.31.255.254"
        $port = 1515
        $reportPath = "$env:USERPROFILE\Desktop\report.txt"
        $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"

        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $client.SendTimeout = 3000
            $client.ReceiveTimeout = 3000

            $connectionTask = $client.ConnectAsync($ip, $port)
            if (-not $connectionTask.Wait(5000)) {
                Write-Host "❌ 連線逾時，無法連接螢幕"
                return $false
            }

            if ($client.Connected) {
                $stream = $client.GetStream()

                $stream.Write($CmdData, 0, $CmdData.Length)

                $hexCommand = ($CmdData | ForEach-Object { $_.ToString("X2") }) -join " "
                Write-Host "✔ 已發送指令：$hexCommand"

                Start-Sleep -Milliseconds 500

                $responseLog = ""
                $isMatched = $false

                if ($stream.DataAvailable) {
                    $buffer = New-Object byte[] 1024
                    $bytesRead = $stream.Read($buffer, 0, $buffer.Length)

                    if ($bytesRead -gt 0) {
                        $response = $buffer[0..($bytesRead - 1)]
                        $hexResponse = ($response | ForEach-Object { $_.ToString("X2") }) -join " "
                        Write-Host "🔄 回應：$hexResponse"

                        if ($ExpectedHex -and $ExpectedHex.Trim().Length -gt 0) {
                            if ($hexResponse -ieq $ExpectedHex.Trim()) {
                                Write-Host "✅ 回應符合預期"
                                $responseLog = @"
[$timestamp] 指令說明：$CmdDesc
  發送指令：$hexCommand
  預期回應：$ExpectedHex
  實際回應：$hexResponse
  ✅ 回應符合預期

"@
                                $isMatched = $true
                            } else {
                                Write-Host "❌ 回應不符合預期"
                                Write-Host "   預期：$ExpectedHex"
                                Write-Host "   實際：$hexResponse"
                                $responseLog = @"
[$timestamp] 指令說明：$CmdDesc
  發送指令：$hexCommand
  預期回應：$ExpectedHex
  實際回應：$hexResponse
  ❌ 回應不符合預期

"@
                            }

                            # 寫入報告檔案
                            #Add-Content -Path $reportPath -Value $responseLog
                        }
                    } else {
                        Write-Host "⚠ 沒有接收到任何回應"
                    }
                } else {
                    Write-Host "⚠ 沒有可用的回應資料"
                }

                $stream.Close()
                $client.Close()

                if ($ExpectedHex) {
                    if ($isMatched) {
                        Write-Host "✅ '$CmdDesc' 執行成功"
                        return $true
                    } else {
                        Write-Host "❌ '$CmdDesc' 執行失敗"
                        return $false
                    }
                } else {
                    Write-Host "✔ '$CmdDesc' 執行完成（未驗證回應）"
                    return $true
                }
            } else {
                Write-Host "❌ 無法與螢幕建立連線"
                return $false
            }
        }
        catch {
            Write-Host "❌ 通訊錯誤：$_"
            try {
                if ($null -ne $stream) { $stream.Close() }
                if ($null -ne $client) { $client.Close() }
            } catch { }
            return $false
        }
    }

    Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $CommandData, $CommandDescription, $ExpectedResponseHex
}

# 使用函數取得最新的 viewer 檔案路徑
$viewerFilePath = Get-LatestViewerFile
$connectionInfo = Get-RemoteConnectionInfo
$remoteSession = New-PSSession -ComputerName $connectionInfo.RemoteHost -Credential $connectionInfo.Credential

Write-Host "`n===== 設定主機乙太網路2私有IP =====`n" -ForegroundColor Cyan
Set-NetworkIP -Session $remoteSession

Start-Sleep -Seconds 5

Write-Host "`n===== 設定螢幕 Network Standby =====`n" -ForegroundColor Cyan
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0xB5, 0x00, 0x01, 0x01, 0xB7)) -CommandDescription "設定 network standby"
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0xB5, 0x00, 0x00, 0xB5)) -CommandDescription "檢查 network standby" -ExpectedResponseHex "AA FF 00 03 41 B5 01 F9"

Start-Sleep -Seconds 5

Write-Host "`n===== 設定螢幕亮度為80 =====`n" -ForegroundColor Cyan
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0x57, 0x00, 0x08, 0x06, 0x00, 0x01 ,0x50, 0x06, 0x00, 0x00, 0x00, 0xBC)) -CommandDescription "設定螢幕亮度為80,0"
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0x57, 0x00, 0x00, 0x57)) -CommandDescription "檢查螢幕亮度設定" -ExpectedResponseHex "AA FF 00 0A 41 57 06 00 01 50 06 00 00 00 FE"

Start-Sleep -Seconds 5

Write-Host "`n===== 重啟螢幕 =====`n" -ForegroundColor Cyan
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0x11, 0x00, 0x01, 0x02, 0x14)) -CommandDescription "重啟螢幕" -ExpectedResponseHex "AA FF 00 03 41 11 02 56"

Start-Sleep -Seconds 30

Write-Host "`n===== 關閉螢幕 =====`n" -ForegroundColor Cyan
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0x11, 0x00, 0x01, 0x00, 0x12)) -CommandDescription "關閉螢幕"
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0x11, 0x00, 0x00, 0x11)) -CommandDescription "檢查螢幕是否關閉" -ExpectedResponseHex "AA FF 00 03 41 11 00 54"

Start-Sleep -Seconds 10

Write-Host "`n===== 開啟螢幕 =====`n" -ForegroundColor Cyan
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0x11, 0x00, 0x01, 0x01, 0x13)) -CommandDescription "開啟螢幕"
Start-Sleep -Seconds 10
Send-DisplayCommand -Session $remoteSession -CommandData ([byte[]] (0xAA, 0x11, 0x00, 0x00, 0x11)) -CommandDescription "檢查螢幕是否開啟" -ExpectedResponseHex "AA FF 00 03 41 11 01 55"