# NetworkAnalyzer PowerShell Module
# Helper functions for network device discovery and analysis

function Get-LocalSubnets {
    <#
    .SYNOPSIS
    Get all local subnet ranges from network adapters
    
    .DESCRIPTION
    Enumerates all active network adapters and returns their subnet information
    #>
    [CmdletBinding()]
    param()
    
    $subnets = @()
    
    # Get all network adapters with IPv4 addresses
    $adapters = Get-NetIPAddress -AddressFamily IPv4 | 
        Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.AddressState -eq "Preferred" }
    
    foreach ($adapter in $adapters) {
        $ip = $adapter.IPAddress
        $prefixLength = $adapter.PrefixLength
        
        # Skip loopback
        if ($ip -eq "127.0.0.1") { continue }
        
        # Calculate network address
        $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
        # Create subnet mask using bitwise operation
        $maskValue = [uint32](0xFFFFFFFF -shl (32 - $prefixLength))
        $maskBytes = [System.BitConverter]::GetBytes($maskValue)
        [Array]::Reverse($maskBytes)
        
        $networkBytes = @(0, 0, 0, 0)
        for ($i = 0; $i -lt 4; $i++) {
            $networkBytes[$i] = $ipBytes[$i] -band $maskBytes[$i]
        }
        
        $networkAddress = [System.Net.IPAddress]::new($networkBytes).ToString()
        
        $subnets += [PSCustomObject]@{
            InterfaceAlias = $adapter.InterfaceAlias
            IPAddress = $ip
            PrefixLength = $prefixLength
            NetworkAddress = $networkAddress
        }
    }
    
    return $subnets
}

function Test-HostAlive {
    <#
    .SYNOPSIS
    Test if a host is alive using ping
    
    .PARAMETER IPAddress
    The IP address to test
    
    .PARAMETER Timeout
    Timeout in milliseconds (default: 1000)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 1000
    )
    
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $result = $ping.Send($IPAddress, $Timeout)
        return ($result.Status -eq 'Success')
    }
    catch {
        return $false
    }
}

function Get-NetworkHosts {
    <#
    .SYNOPSIS
    Scan a subnet for active hosts
    
    .PARAMETER NetworkAddress
    The network address (e.g., "192.168.1.0")
    
    .PARAMETER PrefixLength
    The subnet prefix length (e.g., 24 for /24)
    
    .PARAMETER MaxThreads
    Maximum number of parallel threads (default: 50)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NetworkAddress,
        
        [Parameter(Mandatory = $true)]
        [int]$PrefixLength,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxThreads = 50
    )
    
    Write-Verbose "Scanning subnet $NetworkAddress/$PrefixLength"
    
    # Calculate number of hosts
    $hostCount = [Math]::Pow(2, 32 - $PrefixLength) - 2
    
    # Parse network address
    $networkBytes = [System.Net.IPAddress]::Parse($NetworkAddress).GetAddressBytes()
    $networkInt = [System.BitConverter]::ToUInt32($networkBytes, 0)
    if ([System.BitConverter]::IsLittleEndian) {
        # Convert to host order, handling uint32 properly
        [Array]::Reverse($networkBytes)
        $networkInt = [System.BitConverter]::ToUInt32($networkBytes, 0)
    }
    
    $activeHosts = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
    
    # Use runspaces for parallel scanning
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $runspacePool.Open()
    $jobs = @()
    
    for ($i = 1; $i -le $hostCount; $i++) {
        $hostInt = $networkInt + $i
        # Convert back to bytes in correct order
        $hostBytes = [System.BitConverter]::GetBytes($hostInt)
        if ([System.BitConverter]::IsLittleEndian) {
            [Array]::Reverse($hostBytes)
        }
        $hostIP = [System.Net.IPAddress]::new($hostBytes).ToString()
        
        $powershell = [powershell]::Create().AddScript({
            param($ip, $timeout)
            try {
                $ping = New-Object System.Net.NetworkInformation.Ping
                $result = $ping.Send($ip, $timeout)
                if ($result.Status -eq 'Success') {
                    return $ip
                }
            }
            catch { }
            return $null
        }).AddArgument($hostIP).AddArgument(500)
        
        $powershell.RunspacePool = $runspacePool
        $jobs += @{
            PowerShell = $powershell
            Handle = $powershell.BeginInvoke()
        }
    }
    
    # Collect results
    foreach ($job in $jobs) {
        $result = $job.PowerShell.EndInvoke($job.Handle)
        if ($result) {
            $activeHosts.Add($result)
        }
        $job.PowerShell.Dispose()
    }
    
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    return $activeHosts.ToArray()
}

function Test-TCPPort {
    <#
    .SYNOPSIS
    Test if a TCP port is open on a host
    
    .PARAMETER IPAddress
    The IP address to test
    
    .PARAMETER Port
    The port number to test
    
    .PARAMETER Timeout
    Timeout in milliseconds (default: 1000)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 1000
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($IPAddress, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
        
        if (!$wait) {
            $tcpClient.Close()
            return $false
        }
        
        try {
            $tcpClient.EndConnect($connect)
            $tcpClient.Close()
            return $true
        }
        catch {
            $tcpClient.Close()
            return $false
        }
    }
    catch {
        return $false
    }
}

function Get-OpenPorts {
    <#
    .SYNOPSIS
    Scan common ports on a host
    
    .PARAMETER IPAddress
    The IP address to scan
    
    .PARAMETER Ports
    Array of ports to scan (default: common ports)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $false)]
        [int[]]$Ports = @(21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 3306, 3389, 5000, 5001, 8080, 8081, 8123, 8443, 9000)
    )
    
    $openPorts = @()
    
    foreach ($port in $Ports) {
        Write-Verbose "Testing port $port on $IPAddress"
        if (Test-TCPPort -IPAddress $IPAddress -Port $port -Timeout 500) {
            $openPorts += $port
        }
    }
    
    return $openPorts
}

function Get-HttpService {
    <#
    .SYNOPSIS
    Attempt to get HTTP service information from a host
    
    .PARAMETER IPAddress
    The IP address to query
    
    .PARAMETER Port
    The port to query
    
    .PARAMETER UseSSL
    Whether to use HTTPS
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseSSL
    )
    
    $protocol = if ($UseSSL) { "https" } else { "http" }
    $url = "${protocol}://${IPAddress}:${Port}"
    
    try {
        # Ignore SSL certificate errors for self-signed certificates
        # SECURITY WARNING: This disables SSL certificate validation globally
        # Only use this in trusted network environments for device discovery
        if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
            Add-Type @"
                using System.Net;
                using System.Net.Security;
                using System.Security.Cryptography.X509Certificates;
                public class ServerCertificateValidationCallback {
                    public static void Ignore() {
                        ServicePointManager.ServerCertificateValidationCallback += 
                            delegate (
                                Object obj, 
                                X509Certificate certificate, 
                                X509Chain chain, 
                                SslPolicyErrors errors
                            ) {
                                return true;
                            };
                    }
                }
"@
        }
        [ServerCertificateValidationCallback]::Ignore()
        
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        
        return [PSCustomObject]@{
            URL = $url
            StatusCode = $response.StatusCode
            Server = $response.Headers['Server']
            Title = if ($response.Content -match '<title>(.*?)</title>') { $matches[1] } else { $null }
            Headers = $response.Headers
            Success = $true
        }
    }
    catch {
        return [PSCustomObject]@{
            URL = $url
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-DeviceType {
    <#
    .SYNOPSIS
    Attempt to identify the device type based on open ports and HTTP responses
    
    .PARAMETER IPAddress
    The IP address of the device
    
    .PARAMETER OpenPorts
    Array of open ports on the device
    
    .PARAMETER HttpInfo
    HTTP service information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $false)]
        [int[]]$OpenPorts = @(),
        
        [Parameter(Mandatory = $false)]
        [object[]]$HttpInfo = @()
    )
    
    $deviceType = "Unknown"
    $deviceName = $null
    $apiEndpoints = @()
    
    # Check HTTP responses for device identification
    foreach ($info in $HttpInfo) {
        if ($info.Success) {
            $server = $info.Server -join ','
            $title = $info.Title
            
            # Home Assistant
            if ($title -match 'Home Assistant' -or $server -match 'Home Assistant') {
                $deviceType = "IoT Hub"
                $deviceName = "Home Assistant"
                $apiEndpoints += "$($info.URL)/api/"
            }
            # Shelly devices
            elseif ($title -match 'Shelly' -or $server -match 'Shelly') {
                $deviceType = "IoT Device"
                $deviceName = "Shelly"
                $apiEndpoints += "$($info.URL)/status"
                $apiEndpoints += "$($info.URL)/settings"
            }
            # Ubiquiti
            elseif ($title -match 'UniFi' -or $server -match 'UniFi') {
                $deviceType = "Network/Security Device"
                $deviceName = "Ubiquiti UniFi"
                $apiEndpoints += "$($info.URL)/api/"
            }
            # Node-RED
            elseif ($title -match 'Node-RED' -or $server -match 'Node-RED') {
                $deviceType = "IoT Hub"
                $deviceName = "Node-RED"
                $apiEndpoints += "$($info.URL)/flows"
            }
            # OpenHAB
            elseif ($title -match 'openHAB' -or $server -match 'openHAB') {
                $deviceType = "IoT Hub"
                $deviceName = "openHAB"
                $apiEndpoints += "$($info.URL)/rest/"
            }
            # Generic web server
            elseif ($info.StatusCode -eq 200) {
                $deviceType = "Web Server"
                $deviceName = $server
            }
        }
    }
    
    # Port-based identification
    if ($deviceType -eq "Unknown") {
        if ($OpenPorts -contains 22) { $deviceType = "Linux/Unix Device" }
        elseif ($OpenPorts -contains 3389) { $deviceType = "Windows Device" }
        elseif ($OpenPorts -contains 445) { $deviceType = "SMB/CIFS Device" }
        elseif ($OpenPorts -contains 8123) { 
            $deviceType = "IoT Hub"
            $deviceName = "Possible Home Assistant"
        }
    }
    
    # Try to get hostname
    try {
        $hostname = [System.Net.Dns]::GetHostEntry($IPAddress).HostName
    }
    catch {
        $hostname = $null
    }
    
    return [PSCustomObject]@{
        IPAddress = $IPAddress
        Hostname = $hostname
        DeviceType = $deviceType
        DeviceName = $deviceName
        OpenPorts = $OpenPorts
        ApiEndpoints = $apiEndpoints
    }
}

function Get-ApiEndpoints {
    <#
    .SYNOPSIS
    Discover API endpoints on a device
    
    .PARAMETER IPAddress
    The IP address of the device
    
    .PARAMETER Port
    The port to check
    
    .PARAMETER UseSSL
    Whether to use HTTPS
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseSSL
    )
    
    $protocol = if ($UseSSL) { "https" } else { "http" }
    $baseUrl = "${protocol}://${IPAddress}:${Port}"
    $endpoints = @()
    
    # Common API paths to check
    $commonPaths = @(
        "/api",
        "/api/v1",
        "/api/v2",
        "/rest",
        "/swagger",
        "/openapi.json",
        "/api-docs",
        "/status",
        "/info",
        "/health"
    )
    
    foreach ($path in $commonPaths) {
        try {
            $url = "$baseUrl$path"
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                $endpoints += [PSCustomObject]@{
                    URL = $url
                    StatusCode = $response.StatusCode
                    ContentType = $response.Headers['Content-Type'] -join ','
                }
            }
        }
        catch {
            # Endpoint not available, skip
        }
    }
    
    return $endpoints
}

Export-ModuleMember -Function Get-LocalSubnets, Test-HostAlive, Get-NetworkHosts, Test-TCPPort, Get-OpenPorts, Get-HttpService, Get-DeviceType, Get-ApiEndpoints
