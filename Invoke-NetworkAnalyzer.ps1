<#
.SYNOPSIS
Network Analyzer - Discover devices and API endpoints on local network

.DESCRIPTION
This script scans local network subnets to discover active devices, identify device types,
and find exposed API endpoints. Useful for discovering IoT hubs (Home Assistant, OpenHAB),
IoT devices (Shelly), and security devices (Ubiquiti, Ajax).

.PARAMETER Subnets
Optional array of specific subnets to scan (e.g., @("192.168.1.0/24", "192.168.2.0/24"))
If not specified, all local subnets will be scanned.

.PARAMETER OutputPath
Optional path to save the results as JSON file

.PARAMETER SkipPortScan
Skip detailed port scanning (faster but less accurate device identification)

.PARAMETER Verbose
Show verbose output during scanning

.EXAMPLE
.\Invoke-NetworkAnalyzer.ps1
Scans all local subnets and displays results

.EXAMPLE
.\Invoke-NetworkAnalyzer.ps1 -Subnets @("192.168.1.0/24") -OutputPath "results.json"
Scans specific subnet and saves results to file

.EXAMPLE
.\Invoke-NetworkAnalyzer.ps1 -Verbose
Scans with verbose output to see progress

.NOTES
Requires Windows 11 or Windows 10 with PowerShell 5.1 or later
Some features may require administrator privileges for accurate results
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Subnets,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPortScan
)

# Import the NetworkAnalyzer module
$modulePath = Join-Path $PSScriptRoot "NetworkAnalyzer.psm1"
Import-Module $modulePath -Force

# Track scan start time and prepare output folder
$scanStart = Get-Date
$outputRoot = Join-Path $PSScriptRoot "output"
if (-not (Test-Path -LiteralPath $outputRoot)) {
    New-Item -ItemType Directory -Path $outputRoot | Out-Null
}

# Banner
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "    Network Analyzer - Device Discovery Tool    " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Discover local subnets
Write-Host "[*] Discovering local subnets..." -ForegroundColor Yellow

$subnetsToScan = @()

if ($Subnets) {
    # Parse user-provided subnets
    foreach ($subnet in $Subnets) {
        if ($subnet -match '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})$') {
            # Validate IP address octets (0-255)
            $octet1 = [int]$matches[1]
            $octet2 = [int]$matches[2]
            $octet3 = [int]$matches[3]
            $octet4 = [int]$matches[4]
            $prefix = [int]$matches[5]
            
            if ($octet1 -le 255 -and $octet2 -le 255 -and $octet3 -le 255 -and $octet4 -le 255 -and $prefix -le 32) {
                $ipAddress = "$octet1.$octet2.$octet3.$octet4"
                $subnetsToScan += [PSCustomObject]@{
                    NetworkAddress = $ipAddress
                    PrefixLength = $prefix
                    InterfaceAlias = "User-specified"
                }
            }
            else {
                Write-Warning "Invalid subnet: $subnet (octets must be 0-255, prefix must be 0-32)"
            }
        }
        else {
            Write-Warning "Invalid subnet format: $subnet (expected format: 192.168.1.0/24)"
        }
    }
}
else {
    # Auto-discover local subnets
    $subnetsToScan = Get-LocalSubnets
}

if ($subnetsToScan.Count -eq 0) {
    Write-Host "[!] No subnets found to scan. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Found $($subnetsToScan.Count) subnet(s) to scan:" -ForegroundColor Green
foreach ($subnet in $subnetsToScan) {
    Write-Host "    - $($subnet.NetworkAddress)/$($subnet.PrefixLength) ($($subnet.InterfaceAlias))" -ForegroundColor Gray
}
Write-Host ""

# Step 2: Scan for active hosts
Write-Host "[*] Scanning for active hosts (this may take a few minutes)..." -ForegroundColor Yellow

$allDevices = @()

foreach ($subnet in $subnetsToScan) {
    Write-Host "    Scanning $($subnet.NetworkAddress)/$($subnet.PrefixLength)..." -ForegroundColor Gray
    
    $activeHosts = Get-NetworkHosts -NetworkAddress $subnet.NetworkAddress -PrefixLength $subnet.PrefixLength -Verbose:$VerbosePreference
    
    Write-Host "    Found $($activeHosts.Count) active host(s)" -ForegroundColor Green
    
    # Step 3: Identify devices and scan ports
    foreach ($ip in $activeHosts) {
        Write-Host "    [*] Analyzing $ip..." -ForegroundColor Cyan
        
        $openPorts = @()
        $httpInfo = @()
        
        if (-not $SkipPortScan) {
            # Scan common ports
            $openPorts = Get-OpenPorts -IPAddress $ip -Verbose:$VerbosePreference
            
            if ($openPorts.Count -gt 0) {
                Write-Host "        Open ports: $($openPorts -join ', ')" -ForegroundColor Gray
                
                # Check HTTP/HTTPS services
                foreach ($port in $openPorts) {
                    if ($port -in @(80, 8080, 8081, 8123, 5000, 9000)) {
                        $info = Get-HttpService -IPAddress $ip -Port $port
                        if ($info.Success) {
                            $httpInfo += $info
                        }
                    }
                    if ($port -in @(443, 8443, 5001)) {
                        $info = Get-HttpService -IPAddress $ip -Port $port -UseSSL
                        if ($info.Success) {
                            $httpInfo += $info
                        }
                    }
                }
            }
        }
        
        # Identify device type
        $deviceInfo = Get-DeviceType -IPAddress $ip -OpenPorts $openPorts -HttpInfo $httpInfo
        if (-not $deviceInfo.PSObject.Properties.Match('ApiDetails')) {
            $deviceInfo | Add-Member -NotePropertyName ApiDetails -NotePropertyValue @() -Force
        }
        
        if ($deviceInfo.DeviceName) {
            Write-Host "        Device: $($deviceInfo.DeviceName) [$($deviceInfo.DeviceType)]" -ForegroundColor Green
        }
        else {
            Write-Host "        Device: $($deviceInfo.DeviceType)" -ForegroundColor Gray
        }
        
        if ($deviceInfo.Hostname) {
            Write-Host "        Hostname: $($deviceInfo.Hostname)" -ForegroundColor Gray
        }
        
        if ($deviceInfo.ApiEndpoints.Count -gt 0) {
            Write-Host "        API Endpoints found:" -ForegroundColor Green
            foreach ($endpoint in $deviceInfo.ApiEndpoints) {
                Write-Host "            - $endpoint" -ForegroundColor Gray
            }
        }
        
        # Try to discover additional API endpoints
        if (-not $SkipPortScan -and $openPorts.Count -gt 0) {
            $endpointResults = @()
            foreach ($port in $openPorts) {
                if ($port -in @(80, 8080, 8081, 8123, 5000, 9000)) {
                    $apiEndpoints = Get-ApiEndpoints -IPAddress $ip -Port $port
                    if ($apiEndpoints.Count -gt 0) {
                        foreach ($endpoint in $apiEndpoints) {
                            if ($endpoint.URL -notin $deviceInfo.ApiEndpoints) {
                                $deviceInfo.ApiEndpoints += $endpoint.URL
                                $tags = @()
                                if ($endpoint.IsOpenApi) { $tags += 'OpenAPI' }
                                if ($endpoint.IsSwaggerUI) { $tags += 'Swagger UI' }
                                if ($endpoint.IsOnvif) { $tags += 'ONVIF' }
                                if ($endpoint.IsIgnorableSoapFault) { $tags += 'SOAP Fault ignored' }
                                $tagStr = if ($tags.Count -gt 0) { ' ' + '[' + ($tags -join ', ') + ']' } else { '' }
                                $statusStr = if ($endpoint.StatusCode) { " [$($endpoint.StatusCode)]" } else { '' }
                                $ctypeStr = if ($endpoint.ContentType) { " [$($endpoint.ContentType)]" } else { '' }
                                Write-Host "            - $($endpoint.URL)$statusStr$ctypeStr$tagStr" -ForegroundColor Gray
                            }
                            $endpointResults += $endpoint
                        }
                    }
                }
                if ($port -in @(443, 8443, 5001)) {
                    $apiEndpoints = Get-ApiEndpoints -IPAddress $ip -Port $port -UseSSL
                    if ($apiEndpoints.Count -gt 0) {
                        foreach ($endpoint in $apiEndpoints) {
                            if ($endpoint.URL -notin $deviceInfo.ApiEndpoints) {
                                $deviceInfo.ApiEndpoints += $endpoint.URL
                                $tags = @()
                                if ($endpoint.IsOpenApi) { $tags += 'OpenAPI' }
                                if ($endpoint.IsSwaggerUI) { $tags += 'Swagger UI' }
                                if ($endpoint.IsOnvif) { $tags += 'ONVIF' }
                                if ($endpoint.IsIgnorableSoapFault) { $tags += 'SOAP Fault ignored' }
                                $tagStr = if ($tags.Count -gt 0) { ' ' + '[' + ($tags -join ', ') + ']' } else { '' }
                                $statusStr = if ($endpoint.StatusCode) { " [$($endpoint.StatusCode)]" } else { '' }
                                $ctypeStr = if ($endpoint.ContentType) { " [$($endpoint.ContentType)]" } else { '' }
                                Write-Host "            - $($endpoint.URL)$statusStr$ctypeStr$tagStr" -ForegroundColor Gray
                            }
                            $endpointResults += $endpoint
                        }
                    }
                }
            }
            if ($endpointResults.Count -gt 0) {
                $deviceInfo.ApiDetails = $endpointResults
                if ($deviceInfo.DeviceType -in @('Unknown','Web Server')) {
                    $inferred = Infer-DeviceTypeFromApi -ApiDetails $endpointResults
                    if ($inferred.DeviceType) { $deviceInfo.DeviceType = $inferred.DeviceType }
                    if ($inferred.DeviceName) { $deviceInfo.DeviceName = $inferred.DeviceName }
                }
            }
        }
        
        $allDevices += $deviceInfo
        Write-Host ""
    }
}

# Step 4: Summary
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "    Scan Complete - Summary" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total devices found: $($allDevices.Count)" -ForegroundColor Green
Write-Host ""

# Group by device type
$deviceTypes = $allDevices | Group-Object -Property DeviceType
foreach ($type in $deviceTypes) {
    Write-Host "  $($type.Name): $($type.Count)" -ForegroundColor Cyan
    foreach ($device in $type.Group) {
        $label = if ($device.DeviceName) { $device.DeviceName } else { $device.IPAddress }
        $hostname = if ($device.Hostname) { " ($($device.Hostname))" } else { "" }
        Write-Host "    - $label$hostname - $($device.IPAddress)" -ForegroundColor Gray
    }
}

# Devices with APIs
$devicesWithApis = $allDevices | Where-Object { $_.ApiEndpoints.Count -gt 0 }
if ($devicesWithApis.Count -gt 0) {
    Write-Host ""
    Write-Host "Devices with API endpoints: $($devicesWithApis.Count)" -ForegroundColor Green
    foreach ($device in $devicesWithApis) {
        $hasName = [string]::IsNullOrWhiteSpace($device.DeviceName) -eq $false
        $hasHost = [string]::IsNullOrWhiteSpace($device.Hostname) -eq $false
        $label = if ($hasName -and $hasHost) { "$($device.DeviceName) ($($device.Hostname))" }
                 elseif ($hasName) { $device.DeviceName }
                 elseif ($hasHost) { $device.Hostname }
                 else { "Unknown" }
        Write-Host "  $($device.IPAddress) - $label" -ForegroundColor Cyan
        if ($device.PSObject.Properties.Match('ApiDetails')) {
            foreach ($detail in $device.ApiDetails) {
                $tags = @()
                if ($detail.IsOpenApi) { $tags += 'OpenAPI' }
                if ($detail.IsSwaggerUI) { $tags += 'Swagger UI' }
                if ($detail.IsOnvif) { $tags += 'ONVIF' }
                if ($detail.IsIgnorableSoapFault) { $tags += 'SOAP Fault ignored' }
                $tagStr = if ($tags.Count -gt 0) { ' ' + '[' + ($tags -join ', ') + ']' } else { '' }
                $statusStr = if ($detail.StatusCode) { " [$($detail.StatusCode)]" } else { '' }
                $ctypeStr = if ($detail.ContentType) { " [$($detail.ContentType)]" } else { '' }
                Write-Host "    - $($detail.URL)$statusStr$ctypeStr$tagStr" -ForegroundColor Gray
            }
        }
        else {
            foreach ($endpoint in $device.ApiEndpoints) {
                Write-Host "    - $endpoint" -ForegroundColor Gray
            }
        }
    }
}

# Step 5: Save results if requested
if ($OutputPath) {
    Write-Host ""
    Write-Host "[*] Saving results to $OutputPath..." -ForegroundColor Yellow
    
    $results = @{
        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Subnets = $subnetsToScan
        DeviceCount = $allDevices.Count
        Devices = $allDevices
    }
    
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "[+] Results saved successfully" -ForegroundColor Green
}

# Step 6: Write per-device output to /output
foreach ($device in $allDevices) {
    $nameParts = @()
    if ($device.DeviceName) { $nameParts += $device.DeviceName }
    if ($device.Hostname) { $nameParts += $device.Hostname }
    $nameLabel = if ($nameParts.Count -gt 0) { $nameParts -join " - " } else { "Unknown" }
    $folderName = "${($device.IPAddress)} - ${nameLabel}"
    $safeFolder = ($folderName -replace '[<>:"/\\\|\?\*]', '_').Trim()
    $deviceDir = Join-Path $outputRoot $safeFolder
    if (-not (Test-Path -LiteralPath $deviceDir)) { New-Item -ItemType Directory -Path $deviceDir | Out-Null }

    # Write slim device object (exclude RawContent/Snippet from ApiDetails)
    $deviceSlim = [PSCustomObject]@{
        IPAddress = $device.IPAddress
        Hostname = $device.Hostname
        DeviceType = $device.DeviceType
        DeviceName = $device.DeviceName
        OpenPorts = $device.OpenPorts
        ApiEndpoints = $device.ApiEndpoints
        ApiDetails = @()
    }
    if ($device.PSObject.Properties.Match('ApiDetails') -and $device.ApiDetails.Count -gt 0) {
        $deviceSlim.ApiDetails = @()
        foreach ($d in $device.ApiDetails) {
            $deviceSlim.ApiDetails += [PSCustomObject]@{
                URL = $d.URL
                StatusCode = $d.StatusCode
                ContentType = $d.ContentType
                Server = $d.Server
                Title = $d.Title
                IsJson = $d.IsJson
                JsonKeys = $d.JsonKeys
                IsSwaggerUI = $d.IsSwaggerUI
                IsOpenApi = $d.IsOpenApi
                IsOnvif = $d.IsOnvif
            }
        }
    }
    ($deviceSlim | ConvertTo-Json -Depth 10) | Out-File -FilePath (Join-Path $deviceDir 'device.json') -Encoding UTF8

    # Write endpoint contents when available
    if ($device.PSObject.Properties.Match('ApiDetails') -and $device.ApiDetails.Count -gt 0) {
        $epDir = Join-Path $deviceDir 'endpoints'
        if (-not (Test-Path -LiteralPath $epDir)) { New-Item -ItemType Directory -Path $epDir | Out-Null }
        foreach ($detail in $device.ApiDetails) {
            try {
                $u = [uri]$detail.URL
                $absPath = $u.AbsolutePath.Trim('/')
                $segments = @()
                if (-not [string]::IsNullOrWhiteSpace($absPath)) { $segments = $absPath.Split('/') }
                $lastSeg = ($segments | Where-Object { $_ -ne '' } | Select-Object -Last 1)
                if ([string]::IsNullOrWhiteSpace($lastSeg)) { $lastSeg = 'root' }
                $segSan = $lastSeg -replace '[^a-zA-Z0-9._-]', '_'
                # Include port to avoid collisions across http/https
                $fileBase = "${($u.Port)}_${segSan}"
                $ext = '.txt'
                if ($detail.IsJson -or ($detail.ContentType -match 'json')) { $ext = '.json' }
                elseif ($detail.ContentType -match 'xml' -or ($detail.Snippet -match '<Envelope')) { $ext = '.xml' }
                elseif ($detail.ContentType -match 'html') { $ext = '.html' }
                $contentPath = Join-Path $epDir ($fileBase + $ext)

                # Only write XML file if not an ignorable SOAP fault
                if ($ext -eq '.xml' -and $detail.IsIgnorableSoapFault) {
                    # Remove any old XML file for this endpoint if it exists
                    if (Test-Path -LiteralPath $contentPath) {
                        Remove-Item -LiteralPath $contentPath -Force -ErrorAction SilentlyContinue
                    }
                    # Suppress writing XML file for ignorable SOAP fault
                }
                elseif (-not $detail.IsIgnorableSoapFault -and $detail.RawContent) {
                    if ($ext -eq '.json') {
                        try {
                            ($detail.RawContent | ConvertFrom-Json | ConvertTo-Json -Depth 50) | Out-File -FilePath $contentPath -Encoding UTF8
                        }
                        catch {
                            $detail.RawContent | Out-File -FilePath $contentPath -Encoding UTF8
                        }
                    }
                    elseif ($ext -eq '.xml') {
                        try {
                            $xmlDoc = New-Object System.Xml.XmlDocument
                            $xmlDoc.LoadXml($detail.RawContent)
                            $settings = New-Object System.Xml.XmlWriterSettings
                            $settings.Indent = $true
                            $settings.NewLineOnAttributes = $false
                            $writer = [System.Xml.XmlWriter]::Create($contentPath, $settings)
                            $xmlDoc.Save($writer)
                            $writer.Close()
                        }
                        catch {
                            $detail.RawContent | Out-File -FilePath $contentPath -Encoding UTF8
                        }
                    }
                    else {
                        $detail.RawContent | Out-File -FilePath $contentPath -Encoding UTF8
                    }
                }
                elseif (-not $detail.IsIgnorableSoapFault -and $detail.Snippet) {
                    $detail.Snippet | Out-File -FilePath $contentPath -Encoding UTF8
                }

                # Write metadata sidecar with LastUpdated timestamp
                $meta = [PSCustomObject]@{
                    URL = $detail.URL
                    StatusCode = $detail.StatusCode
                    ContentType = $detail.ContentType
                    Server = $detail.Server
                    Title = $detail.Title
                    IsJson = $detail.IsJson
                    JsonKeys = $detail.JsonKeys
                    IsSwaggerUI = $detail.IsSwaggerUI
                    IsOpenApi = $detail.IsOpenApi
                    IsOnvif = $detail.IsOnvif
                    IsSoapFault = $detail.IsSoapFault
                    IsIgnorableSoapFault = $detail.IsIgnorableSoapFault
                    LastUpdated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                }
                ($meta | ConvertTo-Json -Depth 10) | Out-File -FilePath (Join-Path $epDir ($fileBase + '.meta.json')) -Encoding UTF8
            }
            catch { }
        }
    }
}

Write-Host ""
$scanEnd = Get-Date
$duration = ($scanEnd - $scanStart)
$durationStr = [string]::Format('{0:00}:{1:00}:{2:00}', [int]$duration.Hours, [int]$duration.Minutes, [int]$duration.Seconds)
Write-Host "Scan completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') in $durationStr" -ForegroundColor Cyan

# Ensure clean termination of the script in interactive runs
return
