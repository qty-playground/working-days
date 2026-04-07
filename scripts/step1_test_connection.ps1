# Step 1: Test viewer auth extraction + PSSession connectivity
# Purpose: Verify viewer file parsing and remote PSSession to store host

$transcriptPath = "$env:USERPROFILE\Desktop\step1_test_connection_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $transcriptPath
Write-Host "Transcript: $transcriptPath"
Write-Host "Start time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# 1. Find latest viewer file
$viewerDirectory = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$viewerFile = Get-ChildItem -Path $viewerDirectory -Filter "*_viewer.ps1" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $viewerFile) {
    Write-Host "ERROR: No *_viewer.ps1 found in Downloads" -ForegroundColor Red
    Write-Host "Directory: $viewerDirectory"
    Stop-Transcript
    exit 1
}

Write-Host "Found viewer file: $($viewerFile.Name)"
Write-Host "Last modified: $($viewerFile.LastWriteTime)"

# 2. Extract connection info
$content = Get-Content $viewerFile.FullName -Raw
Write-Host ""
Write-Host "--- Viewer file content (first 500 chars) ---"
Write-Host $content.Substring(0, [Math]::Min(500, $content.Length))
Write-Host "--- End of preview ---"
Write-Host ""

# Extract IP
if ($content -match "\\\\([\d\.]+)") {
    $remoteHost = $matches[1]
    Write-Host "Extracted IP: $remoteHost"
} else {
    Write-Host "ERROR: Failed to extract IP from viewer file" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# Extract username
if ($content -match "-u\s+([\w\\]+)") {
    $username = $matches[1]
    Write-Host "Extracted username: $username"
} else {
    Write-Host "ERROR: Failed to extract username from viewer file" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# Extract password
if ($content -match "-p\s+'([^']+)'") {
    $password = $matches[1]
    Write-Host "Extracted password: (ok, length=$($password.Length))"
} else {
    Write-Host "ERROR: Failed to extract password from viewer file" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# 3. Create PSSession
Write-Host ""
Write-Host "Creating PSSession to $remoteHost ..."
$secPass = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($username, $secPass)

try {
    $session = New-PSSession -ComputerName $remoteHost -Credential $cred -ErrorAction Stop
    Write-Host "PSSession created successfully"
    Write-Host "Session ID: $($session.Id), State: $($session.State)"
} catch {
    Write-Host "ERROR: PSSession creation failed" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}

# 4. Smoke test: Get remote computer info
Write-Host ""
Write-Host "Running Get-ComputerInfo on remote host ..."
try {
    $info = Invoke-Command -Session $session -ScriptBlock {
        Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture, WindowsBuildLabEx | ConvertTo-Json
    } -ErrorAction Stop
    Write-Host "Remote host info:"
    Write-Host $info
    Write-Host ""
    Write-Host "Connection test PASSED"
} catch {
    Write-Host "ERROR: Invoke-Command failed" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.Message)"
}

# 5. Cleanup
Remove-PSSession $session -ErrorAction SilentlyContinue
Write-Host "Session closed"
Write-Host ""
Write-Host "End time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Stop-Transcript
