# Quick Start Guide

Get started with PS-NetworkAnalyzer in 3 easy steps!

## Step 1: Download

Clone the repository or download the files:
```powershell
git clone https://github.com/rajbos/PS-NetworkAnalyzer.git
cd PS-NetworkAnalyzer
```

## Step 2: Run Your First Scan

Open PowerShell and run:
```powershell
.\Invoke-NetworkAnalyzer.ps1
```

That's it! The script will automatically:
- Detect your local network subnets
- Scan for active devices
- Identify device types
- Discover API endpoints

## Step 3: Review Results

The output will show:
- Total devices found
- Device types (IoT Hubs, IoT Devices, Network/Security Devices, etc.)
- IP addresses and hostnames
- Open ports on each device
- Discovered API endpoints

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
```

## Common Usage Patterns

### Save Results to File
```powershell
.\Invoke-NetworkAnalyzer.ps1 -OutputPath "my-network.json"
```

### Scan Specific Subnet
```powershell
.\Invoke-NetworkAnalyzer.ps1 -Subnets @("192.168.1.0/24")
```

### Fast Scan (No Port Details)
```powershell
.\Invoke-NetworkAnalyzer.ps1 -SkipPortScan
```

### See Detailed Progress
```powershell
.\Invoke-NetworkAnalyzer.ps1 -Verbose
```

## What Devices Can Be Found?

The tool can identify:

- **IoT Hubs**: Home Assistant, Node-RED, OpenHAB, Domoticz
- **IoT Devices**: Shelly smart switches/sensors, Tasmota, ESPHome
- **Network Devices**: UniFi controllers, routers, switches
- **Security Devices**: NVRs, IP cameras (ONVIF), Ajax security hubs
- **General Devices**: Web servers, Windows PCs, Linux systems, NAS devices

## Tips for Best Results

1. **Run on Windows 11**: The script is optimized for Windows 11 (also works on Windows 10)
2. **Administrator Mode**: Run PowerShell as Administrator for better network access
3. **Wait for Completion**: Large networks may take several minutes to scan
4. **Check Firewall**: Temporarily disable Windows Firewall if no devices are found
5. **Save Results**: Always use `-OutputPath` to keep a record of your network

## Need Help?

- Check the [README.md](README.md) for detailed documentation
- See [EXAMPLES.md](EXAMPLES.md) for more usage scenarios
- Run `Get-Help .\Invoke-NetworkAnalyzer.ps1 -Full` for complete help

## Troubleshooting

**Problem**: No devices found  
**Solution**: 
- Ensure you're connected to the network
- Try running PowerShell as Administrator
- Check Windows Firewall settings

**Problem**: Scan is very slow  
**Solution**:
- Use `-SkipPortScan` for faster results
- Scan specific subnets instead of all networks

**Problem**: Devices not identified correctly  
**Solution**:
- Some devices may not expose enough information
- Check the open ports manually
- Look at the API endpoints discovered

## Next Steps

Once you've scanned your network:
1. Review the discovered API endpoints
2. Test connecting to IoT hubs and devices
3. Set up scheduled scans to monitor network changes
4. Export results and analyze in Excel or other tools

Happy scanning! 🔍
