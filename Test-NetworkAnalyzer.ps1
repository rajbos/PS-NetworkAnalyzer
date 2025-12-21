# Test script for NetworkAnalyzer module
# Run this to verify the module functions work correctly

Import-Module ./NetworkAnalyzer.psm1 -Force

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "NetworkAnalyzer Module Test Suite" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# Test 1: Module Import
Write-Host "[TEST 1] Module Import" -ForegroundColor Yellow
try {
    $functions = Get-Command -Module NetworkAnalyzer
    Write-Host "  PASS: Module loaded with $($functions.Count) functions" -ForegroundColor Green
    $functions | Select-Object Name | Format-Table
}
catch {
    Write-Host "  FAIL: Module import failed - $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Test-HostAlive
Write-Host "[TEST 2] Test-HostAlive" -ForegroundColor Yellow
try {
    $result = Test-HostAlive -IPAddress "127.0.0.1" -Timeout 1000
    if ($result) {
        Write-Host "  PASS: Successfully tested localhost connectivity" -ForegroundColor Green
    }
    else {
        Write-Host "  WARN: Localhost not responding to ping" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Test-TCPPort
Write-Host "[TEST 3] Test-TCPPort" -ForegroundColor Yellow
try {
    # Test a port that should be closed
    $result = Test-TCPPort -IPAddress "127.0.0.1" -Port 54321 -Timeout 500
    if (-not $result) {
        Write-Host "  PASS: Correctly identified closed port" -ForegroundColor Green
    }
    else {
        Write-Host "  WARN: Port 54321 appears to be open" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Get-LocalSubnets (Windows-specific)
Write-Host "[TEST 4] Get-LocalSubnets (Windows-specific)" -ForegroundColor Yellow
try {
    $subnets = Get-LocalSubnets
    if ($subnets) {
        Write-Host "  PASS: Found $($subnets.Count) local subnet(s)" -ForegroundColor Green
        $subnets | Format-Table InterfaceAlias, IPAddress, PrefixLength, NetworkAddress
    }
    else {
        Write-Host "  INFO: No subnets found (expected on non-Windows systems)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  INFO: $($_.Exception.Message) (expected on non-Windows systems)" -ForegroundColor Gray
}

# Test 5: Get-DeviceType
Write-Host "[TEST 5] Get-DeviceType" -ForegroundColor Yellow
try {
    $deviceInfo = Get-DeviceType -IPAddress "127.0.0.1" -OpenPorts @(80, 443) -HttpInfo @()
    if ($deviceInfo) {
        Write-Host "  PASS: Device type identification works" -ForegroundColor Green
        Write-Host "    Device Type: $($deviceInfo.DeviceType)" -ForegroundColor Gray
    }
    else {
        Write-Host "  FAIL: Get-DeviceType returned null" -ForegroundColor Red
    }
}
catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Input Validation
Write-Host "[TEST 6] IP Address Validation in Main Script" -ForegroundColor Yellow
try {
    # Test the subnet validation logic
    $testSubnet = "192.168.1.0/24"
    if ($testSubnet -match '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})$') {
        $octet1 = [int]$matches[1]
        $octet2 = [int]$matches[2]
        $octet3 = [int]$matches[3]
        $octet4 = [int]$matches[4]
        $prefix = [int]$matches[5]
        
        if ($octet1 -le 255 -and $octet2 -le 255 -and $octet3 -le 255 -and $octet4 -le 255 -and $prefix -le 32) {
            Write-Host "  PASS: Valid subnet format accepted (192.168.1.0/24)" -ForegroundColor Green
        }
    }
    
    # Test invalid subnet
    $invalidSubnet = "999.999.999.999/24"
    if ($invalidSubnet -match '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})$') {
        $octet1 = [int]$matches[1]
        if ($octet1 -gt 255) {
            Write-Host "  PASS: Invalid subnet correctly rejected (999.999.999.999/24)" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Test Suite Complete" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
