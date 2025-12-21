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
        # Skip invalid prefix lengths
        if ($prefixLength -lt 0 -or $prefixLength -gt 32) { continue }
        
        # Calculate network address
        $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
        
        # Create subnet mask bytes safely without negative shifts
        # Compute, per octet, how many bits belong to the network portion
        $maskBytes = New-Object 'System.Byte[]' 4
        for ($i = 0; $i -lt 4; $i++) {
            $bits = [math]::Min([math]::Max($prefixLength - (8 * $i), 0), 8)
            if ($bits -le 0) {
                $maskBytes[$i] = [byte]0
            }
            elseif ($bits -ge 8) {
                $maskBytes[$i] = [byte]255
            }
            else {
                # Left shift within byte and mask to 8 bits
                $maskBytes[$i] = [byte]((0xFF -shl (8 - $bits)) -band 0xFF)
            }
        }

        $networkBytes = @(0, 0, 0, 0)
        for ($i = 0; $i -lt 4; $i++) {
            $networkBytes[$i] = $ipBytes[$i] -band $maskBytes[$i]
        }
        
        $networkAddress = [System.Net.IPAddress]::new($networkBytes).ToString()
        # Skip invalid network address results
        if ($networkAddress -eq "0.0.0.0") { continue }
        
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
        # Use PowerShell's built-in certificate skipping option for HTTPS
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop -SkipCertificateCheck:$UseSSL
        
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
        [object[]]$HttpInfo = @(),

        [Parameter(Mandatory = $false)]
        [object[]]$ApiDetails = @()
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
        ApiDetails = $ApiDetails
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
        $url = "$baseUrl$path"
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop -SkipCertificateCheck:$UseSSL -MaximumRedirection 2
            $status = $response.StatusCode
            $ctype = ($response.Headers['Content-Type'] -join ',')
            $server = ($response.Headers['Server'] -join ',')
            $raw = $response.Content
        }
        catch {
            # Still capture non-200 if available (e.g., 401 Unauthorized with useful headers)
            $err = $_.Exception
            $status = $null
            $ctype = $null
            $server = $null
            $raw = $null
        }

        # Only record if reachable or provided a response
        if ($status) {
            $snippet = $null
            $isJson = $false
            $jsonKeys = @()
            $isSwaggerUI = $false
            $isOpenApi = $false
            $isOnvif = $false
            $isSoapFault = $false
            $isIgnorableSoapFault = $false
            $title = $null

            if ($raw) {
                $snippet = if ($raw.Length -gt 512) { $raw.Substring(0,512) } else { $raw }

                # HTML title
                if ($snippet -match '<title>(.*?)</title>') { $title = $matches[1] }

                # JSON detection
                if ($ctype -match 'application/(json|.*\+json)' -or ($snippet -match '^\s*[{\[]')) {
                    try {
                        $json = $raw | ConvertFrom-Json -ErrorAction Stop
                        $isJson = $true
                        if ($json -is [System.Collections.IDictionary]) {
                            $jsonKeys = @($json.Keys) | Select-Object -First 10
                        }
                        elseif ($json -is [System.Collections.IEnumerable]) {
                            $first = ($json | Select-Object -First 1)
                            if ($first -and $first.PSObject.Properties.Name.Count -gt 0) {
                                $jsonKeys = @($first.PSObject.Properties.Name) | Select-Object -First 10
                            }
                        }
                        # OpenAPI detection
                        if ($json.openapi) { $isOpenApi = $true }
                        if ($json.swagger) { $isOpenApi = $true }
                    }
                    catch { }
                }

                # Swagger UI detection
                if ($snippet -match 'Swagger UI' -or $snippet -match 'id="swagger-ui"') { $isSwaggerUI = $true }

                # ONVIF/SOAP detection
                if (($ctype -match 'application/soap\+xml') -or ($snippet -match '<(s:Envelope|SOAP-ENV:Envelope|Envelope)')) {
                    if ($snippet -match 'onvif' -or $snippet -match 'www\.onvif\.org') { $isOnvif = $true }
                    if ($snippet -match '<(s:Fault|SOAP-ENV:Fault|Fault)') { $isSoapFault = $true }
                    if ($snippet -match 'End of file or no input: message transfer interrupted') { $isIgnorableSoapFault = $true }
                }
            }

            # Suppress saving noisy SOAP fault content
            if ($isIgnorableSoapFault) {
                $raw = $null
                $snippet = $null
            }

            $endpoints += [PSCustomObject]@{
                URL = $url
                StatusCode = $status
                ContentType = $ctype
                Server = $server
                Title = $title
                IsJson = $isJson
                JsonKeys = $jsonKeys
                IsSwaggerUI = $isSwaggerUI
                IsOpenApi = $isOpenApi
                IsOnvif = $isOnvif
                Snippet = $snippet
                RawContent = $raw
                IsSoapFault = $isSoapFault
                IsIgnorableSoapFault = $isIgnorableSoapFault
            }
        }
    }

    return $endpoints
}

function Infer-DeviceTypeFromApi {
    <#
    .SYNOPSIS
    Infer device type/name from analyzed API endpoint details
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ApiDetails
    )

    $deviceType = $null
    $deviceName = $null

    if ($ApiDetails | Where-Object { $_.IsOnvif }) {
        $deviceType = "Network/Security Device"
        $deviceName = "ONVIF Camera/NVR"
        return @{ DeviceType = $deviceType; DeviceName = $deviceName }
    }

    if ($ApiDetails | Where-Object { $_.IsOpenApi -or $_.IsSwaggerUI }) {
        $deviceType = "Web Server"
        $deviceName = "OpenAPI Service"
        return @{ DeviceType = $deviceType; DeviceName = $deviceName }
    }

    # Fallback: if many JSON endpoints exist, likely a generic web API service
    $jsonCount = ($ApiDetails | Where-Object { $_.IsJson }).Count
    if ($jsonCount -ge 2) {
        $deviceType = "Web Server"
        $deviceName = $null
        return @{ DeviceType = $deviceType; DeviceName = $deviceName }
    }

    return @{ DeviceType = $null; DeviceName = $null }
}

Export-ModuleMember -Function Get-LocalSubnets, Test-HostAlive, Get-NetworkHosts, Test-TCPPort, Get-OpenPorts, Get-HttpService, Get-DeviceType, Get-ApiEndpoints, Infer-DeviceTypeFromApi
