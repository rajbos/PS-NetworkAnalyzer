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
    foreach ($host in $activeHosts) {
        Write-Host "    [*] Analyzing $host..." -ForegroundColor Cyan
        
        $openPorts = @()
        $httpInfo = @()
        
        if (-not $SkipPortScan) {
            # Scan common ports
            $openPorts = Get-OpenPorts -IPAddress $host -Verbose:$VerbosePreference
            
            if ($openPorts.Count -gt 0) {
                Write-Host "        Open ports: $($openPorts -join ', ')" -ForegroundColor Gray
                
                # Check HTTP/HTTPS services
                foreach ($port in $openPorts) {
                    if ($port -in @(80, 8080, 8081, 8123, 5000, 9000)) {
                        $info = Get-HttpService -IPAddress $host -Port $port
                        if ($info.Success) {
                            $httpInfo += $info
                        }
                    }
                    if ($port -in @(443, 8443, 5001)) {
                        $info = Get-HttpService -IPAddress $host -Port $port -UseSSL
                        if ($info.Success) {
                            $httpInfo += $info
                        }
                    }
                }
            }
        }
        
        # Identify device type
        $deviceInfo = Get-DeviceType -IPAddress $host -OpenPorts $openPorts -HttpInfo $httpInfo
        
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
            foreach ($port in $openPorts) {
                if ($port -in @(80, 8080, 8081, 8123, 5000, 9000)) {
                    $apiEndpoints = Get-ApiEndpoints -IPAddress $host -Port $port
                    if ($apiEndpoints.Count -gt 0) {
                        foreach ($endpoint in $apiEndpoints) {
                            if ($endpoint.URL -notin $deviceInfo.ApiEndpoints) {
                                $deviceInfo.ApiEndpoints += $endpoint.URL
                                Write-Host "            - $($endpoint.URL) [$($endpoint.ContentType)]" -ForegroundColor Gray
                            }
                        }
                    }
                }
                if ($port -in @(443, 8443, 5001)) {
                    $apiEndpoints = Get-ApiEndpoints -IPAddress $host -Port $port -UseSSL
                    if ($apiEndpoints.Count -gt 0) {
                        foreach ($endpoint in $apiEndpoints) {
                            if ($endpoint.URL -notin $deviceInfo.ApiEndpoints) {
                                $deviceInfo.ApiEndpoints += $endpoint.URL
                                Write-Host "            - $($endpoint.URL) [$($endpoint.ContentType)]" -ForegroundColor Gray
                            }
                        }
                    }
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
        Write-Host "  $($device.IPAddress) - $($device.DeviceName)" -ForegroundColor Cyan
        foreach ($endpoint in $device.ApiEndpoints) {
            Write-Host "    - $endpoint" -ForegroundColor Gray
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

Write-Host ""
Write-Host "Scan completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
