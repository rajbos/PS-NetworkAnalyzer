# PS-NetworkAnalyzer

A PowerShell-based network device discovery tool for Windows 11 that scans local LAN subnets to identify devices, determine device types, and discover exposed API endpoints.

## Features

- **Automatic Subnet Discovery**: Automatically detects and scans all local network subnets
- **Multi-Subnet Support**: Can scan multiple subnets in parallel
- **Device Type Identification**: Identifies various device types including:
  - IoT Hubs (Home Assistant, Node-RED, OpenHAB)
  - IoT Devices (Shelly devices)
  - Network/Security Devices (Ubiquiti UniFi)
  - Generic web servers and other network devices
- **Port Scanning**: Scans common ports to identify services
- **API Endpoint Discovery**: Automatically discovers exposed API endpoints on devices
- **Fast Parallel Scanning**: Uses PowerShell runspaces for efficient multi-threaded scanning

## Requirements

- Windows 11 or Windows 10
- PowerShell 5.1 or later
- Network connectivity to local LAN

## Installation

1. Clone or download this repository:
```powershell
git clone https://github.com/rajbos/PS-NetworkAnalyzer.git
cd PS-NetworkAnalyzer
```

2. No additional installation required - the script is ready to use!

## Usage

### Basic Usage

Scan all local subnets:
```powershell
.\Invoke-NetworkAnalyzer.ps1
```

### Scan Specific Subnets

Scan one or more specific subnets:
```powershell
.\Invoke-NetworkAnalyzer.ps1 -Subnets @("192.168.1.0/24", "192.168.2.0/24")
```

### Save Results to File

Save scan results as JSON:
```powershell
.\Invoke-NetworkAnalyzer.ps1 -OutputPath "scan-results.json"
```

### Fast Scan (Skip Port Scanning)

For quick host discovery without detailed port scanning:
```powershell
.\Invoke-NetworkAnalyzer.ps1 -SkipPortScan
```

### Verbose Output

See detailed progress during scanning:
```powershell
.\Invoke-NetworkAnalyzer.ps1 -Verbose
```

## Example Output

```
=================================================
    Network Analyzer - Device Discovery Tool    
=================================================

[*] Discovering local subnets...
[+] Found 1 subnet(s) to scan:
    - 192.168.1.0/24 (Ethernet)

[*] Scanning for active hosts (this may take a few minutes)...
    Scanning 192.168.1.0/24...
    Found 5 active host(s)
    [*] Analyzing 192.168.1.1...
        Open ports: 80, 443
        Device: Ubiquiti UniFi [Network/Security Device]
        API Endpoints found:
            - https://192.168.1.1:443/api/

    [*] Analyzing 192.168.1.100...
        Open ports: 8123
        Device: Home Assistant [IoT Hub]
        API Endpoints found:
            - http://192.168.1.100:8123/api/

=================================================
    Scan Complete - Summary
=================================================

Total devices found: 5

  IoT Hub: 1
    - Home Assistant - 192.168.1.100
  Network/Security Device: 1
    - Ubiquiti UniFi - 192.168.1.1
  Unknown: 3
    - 192.168.1.2
    - 192.168.1.50
    - 192.168.1.51

Devices with API endpoints: 2
  192.168.1.1 - Ubiquiti UniFi
    - https://192.168.1.1:443/api/
  192.168.1.100 - Home Assistant
    - http://192.168.1.100:8123/api/
```

## Detected Device Types

The tool can identify the following device types:

- **IoT Hubs**: Home Assistant, Node-RED, OpenHAB
- **IoT Devices**: Shelly smart home devices
- **Network/Security Devices**: Ubiquiti UniFi controllers
- **Generic Devices**: Web servers, SMB/CIFS devices, Windows/Linux hosts

## Common Ports Scanned

The tool scans the following common ports by default:
- 21 (FTP)
- 22 (SSH)
- 23 (Telnet)
- 25 (SMTP)
- 53 (DNS)
- 80 (HTTP)
- 110 (POP3)
- 143 (IMAP)
- 443 (HTTPS)
- 445 (SMB)
- 3306 (MySQL)
- 3389 (RDP)
- 5000, 5001 (Common web services)
- 8080, 8081, 8123, 8443 (Alternative HTTP/HTTPS ports)
- 9000 (Various services)

## Module Functions

The `NetworkAnalyzer.psm1` module provides the following functions that can be used independently:

- `Get-LocalSubnets` - Enumerate local network subnets
- `Test-HostAlive` - Ping test for a single host
- `Get-NetworkHosts` - Scan subnet for active hosts
- `Test-TCPPort` - Test if a TCP port is open
- `Get-OpenPorts` - Scan multiple ports on a host
- `Get-HttpService` - Get HTTP/HTTPS service information
- `Get-DeviceType` - Identify device type
- `Get-ApiEndpoints` - Discover API endpoints

## Security Considerations

- The tool performs network scanning which may be logged by network security devices
- Some firewalls or security software may flag the scanning activity
- SSL certificate validation is disabled for HTTPS connections to allow scanning of devices with self-signed certificates
- Run with appropriate permissions and only on networks you own or have permission to scan

## Limitations

- Device identification depends on HTTP headers and service responses, so not all devices may be accurately identified
- Some devices may have firewalls that block port scanning
- Large subnets (e.g., /16 or larger) may take significant time to scan
- Devices that don't respond to ping may not be detected

## Troubleshooting

### No Devices Found

- Ensure you're connected to the network
- Check if Windows Firewall is blocking ICMP (ping) requests
- Try running PowerShell as Administrator

### Slow Scanning

- Use `-SkipPortScan` for faster host discovery
- Scan specific subnets instead of all subnets
- Reduce the number of threads if system resources are limited

### False Device Identification

- The tool uses heuristics for device identification
- Check open ports and API endpoints manually if unsure
- Some devices may not expose enough information for accurate identification

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

See LICENSE file for details.