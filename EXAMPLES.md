# Example Configuration and Usage Scenarios

## Scenario 1: Quick Home Network Scan

Scan your home network to find all devices:

```powershell
.\Invoke-NetworkAnalyzer.ps1
```

This will automatically detect your local subnets and scan them.

## Scenario 2: Scan Specific IoT Network

If you have a dedicated IoT subnet (e.g., 192.168.50.0/24):

```powershell
.\Invoke-NetworkAnalyzer.ps1 -Subnets @("192.168.50.0/24") -OutputPath "iot-devices.json"
```

## Scenario 3: Multiple Subnets with Different VLANs

Scan multiple network segments:

```powershell
$subnets = @(
    "192.168.1.0/24",   # Main network
    "192.168.10.0/24",  # IoT network
    "192.168.20.0/24"   # Guest network
)
.\Invoke-NetworkAnalyzer.ps1 -Subnets $subnets -Verbose -OutputPath "full-scan.json"
```

## Scenario 4: Quick Device Discovery (No Port Scan)

Fast scan to just identify active hosts:

```powershell
.\Invoke-NetworkAnalyzer.ps1 -SkipPortScan
```

## Using the Module Functions Independently

### Example: Test if Home Assistant is Running

```powershell
Import-Module .\NetworkAnalyzer.psm1

# Test if Home Assistant port is open
if (Test-TCPPort -IPAddress "192.168.1.100" -Port 8123) {
    Write-Host "Home Assistant is running!"
    
    # Get service info
    $info = Get-HttpService -IPAddress "192.168.1.100" -Port 8123
    Write-Host "Service: $($info.Server)"
}
```

### Example: Scan Specific Host for APIs

```powershell
Import-Module .\NetworkAnalyzer.psm1

$ip = "192.168.1.50"

# Get open ports
$ports = Get-OpenPorts -IPAddress $ip
Write-Host "Open ports on $ip: $($ports -join ', ')"

# Check for APIs on web ports
foreach ($port in @(80, 443, 8080, 8123)) {
    if ($ports -contains $port) {
        $useSSL = $port -in @(443, 8443)
        $endpoints = Get-ApiEndpoints -IPAddress $ip -Port $port -UseSSL:$useSSL
        
        if ($endpoints) {
            Write-Host "Found API endpoints on port $port:"
            $endpoints | Format-Table URL, ContentType
        }
    }
}
```

### Example: Custom Port List

```powershell
Import-Module .\NetworkAnalyzer.psm1

# Scan for specific services only
$customPorts = @(22, 80, 443, 8123, 1883, 8883)  # SSH, HTTP, HTTPS, HA, MQTT
$openPorts = Get-OpenPorts -IPAddress "192.168.1.100" -Ports $customPorts

Write-Host "Open ports: $($openPorts -join ', ')"
```

## Common Device Ports Reference

### IoT Hubs
- **Home Assistant**: 8123 (HTTP)
- **Node-RED**: 1880 (HTTP)
- **OpenHAB**: 8080, 8443 (HTTP/HTTPS)
- **Domoticz**: 8080 (HTTP)

### IoT Protocols
- **MQTT**: 1883 (unencrypted), 8883 (encrypted)
- **CoAP**: 5683 (UDP)
- **Zigbee2MQTT**: 8080 (HTTP API)

### Smart Home Devices
- **Shelly Devices**: 80 (HTTP API)
- **Tasmota**: 80 (HTTP)
- **ESPHome**: 6053 (API)

### Network/Security
- **UniFi Controller**: 8443 (HTTPS)
- **UniFi Inform**: 8080
- **Ubiquiti Discovery**: 10001 (UDP)

### Cameras/NVR
- **ONVIF**: 80, 8000, 8080 (various implementations)
- **RTSP**: 554, 8554

## Scheduled Scanning

To run the scan automatically, create a scheduled task:

### PowerShell Script for Scheduled Task

Save as `Scheduled-NetworkScan.ps1`:

```powershell
$scriptPath = "C:\Path\To\PS-NetworkAnalyzer\Invoke-NetworkAnalyzer.ps1"
$outputPath = "C:\Path\To\Logs\network-scan-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

& $scriptPath -OutputPath $outputPath

# Optional: Clean up old scan files (keep last 30 days)
$logDir = Split-Path $outputPath
Get-ChildItem $logDir -Filter "network-scan-*.json" | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item
```

### Create Scheduled Task (Run as Administrator)

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\Path\To\Scheduled-NetworkScan.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName "Network Device Scanner" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Daily network device scan"
```

## Analyzing Results

### Load and Analyze JSON Results

```powershell
$results = Get-Content "scan-results.json" | ConvertFrom-Json

# Show devices by type
$results.Devices | Group-Object DeviceType | ForEach-Object {
    Write-Host "`n$($_.Name): $($_.Count) device(s)"
    $_.Group | Format-Table IPAddress, DeviceName, Hostname
}

# Show all API endpoints
$results.Devices | Where-Object { $_.ApiEndpoints.Count -gt 0 } | ForEach-Object {
    Write-Host "`n$($_.IPAddress) - $($_.DeviceName)"
    $_.ApiEndpoints | ForEach-Object { Write-Host "  $_" }
}

# Export to CSV
$results.Devices | Export-Csv "devices.csv" -NoTypeInformation
```

## Tips and Best Practices

1. **First Run**: Start with `Invoke-NetworkAnalyzer.ps1 -Verbose` to see what's happening
2. **Large Networks**: Use `-SkipPortScan` for initial discovery, then scan specific hosts in detail
3. **Regular Scans**: Schedule daily/weekly scans to track network changes
4. **Save Results**: Always use `-OutputPath` to keep historical records
5. **Custom Analysis**: Import saved JSON results for custom analysis and reporting
6. **Security**: Only scan networks you own or have permission to scan
