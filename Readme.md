# Connect-CiscoVPN
## Description

Changes the IPv4 & IPv6 interface metric of the VPN adapter. The script will run while VPN is connected and periodically checks to make sure values have not changed.
* Optionally (but recommended) will run IPCONFIG /RELEASE6 which clears the DHCP-assigned IPv6 address on the local interface, forcing Windows to use the IPv4-configured DNS server(s).
* Optionally will launch the Cisco AnyConnect client and wait for the VPN connection to connect (if not already connected).
* Optionally will start an RDP session after changing the interface metrics (if an RDP session is not already running).

## Usage
Connect-CiscoVPN **-LAN_if** *<LAN_Interface_Alias>* **-VPN_if** *<VPN_Interface_Alias>* [-Metric [integer]] [-VPNTimeout [Integer]] [-Interval [integer]] [-DisableIPv6] [-AnyConnect] [-RDPHost]<br>

Parameters:<br>
(Required) -LAN_if - Specify the local network interface alias.<br>
(Required) -VPN_if - Specify the VPN interface alias.<br>
(Optional) -Metric - Specify an interface metric for the VPN interface (in seconds). Default is 10.<br>
(Optional) -VPNTimeout - Specify the timeout value (in seconds) to wait for the VPN to connect. Default is 90.<br>
(Optional) -Interval - Specify a recheck interval (in seconds). Default is 60.<br>
(Optional) -DisableIPv6 - Releases the IPv6 DHCP address on the local interface (to force DNS over IPv4).<br>
(Optional) -AnyConnect - Launches the 32-bit or 64-bit version of the Cisco AnyConnect client if in it's default installation directory and pauses the script for *VPNTimeout* seconds.<br>
(Optional) -RDPHost - Specify the name or IP address of remote computer to start a Remote Desktop Protocol session with.<br>

### If Cloning Repo:
This repository makes use of a submodule. After cloning, run the following commands in this script's repo directory to retrieve the files:<br>
**git submodule init**<br>
**git submodule update** 
