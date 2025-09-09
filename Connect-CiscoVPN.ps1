<#PSScriptInfo

.VERSION 0.8.0

.GUID 3cb7bd04-fef8-4ada-ac62-21ef9700769c

.AUTHOR Brad Eley (brad.eley@gmail.com)

.COMPANYNAME 

.COPYRIGHT 
(c) 2025 Brad Eley (brad.eley@gmail.com)
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

.TAGS 

.LICENSEURI https://www.gnu.org/licenses/

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
6/6/2025    0.5.0   Initial prerelease.
9/8/2025    0.7.0   Added Show-Header function.
9/9/2025    0.8.0   Added RDP session launch functionality.

.PRIVATEDATA

#>

<#

.DESCRIPTION
Connects to AnyConnect VPN and reconfigures local network adapter to have the higher metric for local DNS resolution.

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
        $LAN_if,

    [Parameter(Mandatory)]
    [string]
        $VPN_if,

    [int]
        $Metric = 10,

    [int]
        $VPNTimeout = 90,

    [int]
        $Interval = 60,

    [switch]
        $DisableIPv6,
    
    [switch]
        $AnyConnect,
    
    [string]
        $RDPHost,

    [switch]
        $Elevated
)

### INCLUDES ####################

Import-Module $PSScriptRoot\PSModules\EL-PS-Common.psm1

#################################
### VARIABLES ###################

$ErrorActionPreference = "Stop"
$Connected = $null
$VPNclientx86 = "C:\Program Files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe"
$VPNclientx64 = "C:\Program Files\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe"

If ( $AnyConnect ){
    
    If ( Test-Path -Path $VPNclientx86 ){
        $VPNCLI = $VPNclientx86
    }
    ElseIf ( Test-Path -Path $VPNclientx64 ){
        $VPNCLI = $VPNclientx64
    }
    Else {
        Write-Error -Message "Could not find Cisco AnyConnect Secure Mobility Client. Please install the client or rerun the script without the -AnyConnect switch." -ErrorId 89 -TargetObject $_
        exit 89
    }
}

#################################
### FUNCTIONS ###################

Function Show-Header($Path) {
    Clear-Host
    Write-Output "Connect-CiscoVPN PowerShell Script"
    Write-Output "Script version: $((Test-ScriptFileInfo -Path $Path).Version)`n"
}

##################################
### SCRIPT BODY ##################

## Check that script is running with elevated access
If( !(Test-Admin) ){
    Write-Warning -Message "Script ran with non-elevated privleges."
    If( !$Elevated ){
        Write-Output "Attempting script restart in elevated mode..."
        $AllParameters_String = ""
        
        ForEach( $Parameter in $PSBoundParameters.GetEnumerator() ){
            $Parameter_Key = $Parameter.Key;
            $Parameter_Value = $Parameter.Value;
            $Parameter_Value_Type = $Parameter_Value.GetType().Name;
    
            If( $Parameter_Value_Type -Eq "SwitchParameter" ){
                $AllParameters_String += " -$Parameter_Key";
            }
            Else{ $AllParameters_String += " -$Parameter_Key `"$Parameter_Value`"" }
        }
    
        $Arguments= @("-NoProfile","-NoExit","-File",$PSCommandPath,"-Elevated",$AllParameters_String)
        Start-Process PowerShell -Verb Runas -ArgumentList $Arguments
        exit 0
    } 
    # Tried to elevate but it didn't work.
    Write-Error -Message "Could not elevate privleges. Please restart PowerShell in elevated mode before running this script again." -ErrorId 99 -TargetObject $_
    exit 99
}

### MAIN #########################

## If specified, connect to VPN if not already connected
If ( $AnyConnect ){
    Show-Header -Path $MyInvocation.MyCommand.Path
    If ( (Get-NetIPInterface -ErrorAction SilentlyContinue -InterfaceAlias $VPN_if | Where-Object { $_.AddressFamily -eq "IPv4" }).ConnectionState -ne "Connected" ){
        Write-Output "VPN is not connected. Attempting to connect..."
        
        # Start the VPN client
        Start-Process -FilePath $VPNCLI
        
        # Wait for the VPN client to connect
        $tmout = (Get-Date).AddSeconds($VPNTimeout)
        While( $Connected -ne "Connected" -and $tmout -ge (Get-Date) -and [bool](Get-Process "vpnui" -ErrorAction SilentlyContinue) ){
            $Connected = (Get-NetIPInterface -ErrorAction SilentlyContinue -InterfaceAlias $VPN_if | Where-Object { $_.AddressFamily -eq "IPv4" }).ConnectionState
            Start-Sleep -Seconds 1
        }
        
        # Check if the VPN connection was established
        If ( !([bool](Get-Process "vpnui" -ErrorAction SilentlyContinue)) ){
            Write-Error -Message "VPN UI was closed before connecting." -ErrorId 79 -TargetObject $_
            exit 79
        }
        ElseIf ( $Connected -ne "Connected" ){
            Write-Error -Message "Timeout waiting for VPN Connection." -ErrorId 78 -TargetObject $_
            exit 78
        }
        Else { Write-Output "VPN connected successfully." }
    }
    Else { Write-Output "VPN is already connected." }
}

## Main loop to check and reset interface metrics
While ({
  Try   { $Connected = (Get-NetIPInterface -InterfaceAlias $VPN_if | Where-Object { $_.AddressFamily -eq "IPv4" }).ConnectionState }
  Catch {$Connected = $false }
  $Connected -eq "Connected"
  }){
    Show-Header -Path $MyInvocation.MyCommand.Path
    Write-Output "Checking Interface Metrics..."
    # Check and reset VPN interface metric
    If( (Get-NetIPInterface -InterfaceAlias $VPN_if).InterfaceMetric -ne $Metric ){
        Write-Output "VPN Interface Metric out-of-scope. Resetting..."
        Set-NetIPInterface -InterfaceAlias $VPN_if -InterfaceMetric $Metric
    }
    # Check and reset LAN interface metric
    If( (Get-NetIPInterface -InterfaceAlias $LAN_if).InterfaceMetric -ne 1 ){ 
        Write-Output "LAN Interface Metric out-of-scope. Resetting..."
        Set-NetIPInterface -InterfaceAlias $LAN_if -InterfaceMetric 1
    }
    # Release IPv6 DHCP address if option was specified
    If ( $DisableIPv6 ){
        Write-Output "Releasing IPv6 address on $LAN_if..."
        Invoke-Command -ScriptBlock { ipconfig /release6 | Out-Null }
    }
    # Flush DNS cache
    Write-Output "Flushing DNS cache..."
    Invoke-Command -ScriptBlock { ipconfig /flushdns | Out-Null }
    # Launch RDP session if specified and not already running
    If ( $RDPHost -and -not (Get-Process -Name "mstsc" -ErrorAction SilentlyContinue) ){
        Write-Output "Launching RDP session to $RDPHost..."
        Start-Process -FilePath "mstsc.exe" -ArgumentList "/v:$RDPHost"
    }
    # Wait before next check
    $origpos = $host.UI.RawUI.CursorPosition
    $timespan = New-TimeSpan -Seconds $Interval
    $timeout = (Get-Date).Add($timespan)
    While( (Get-Date) -lt $timeout ){
        $remaining = ($timeout - (Get-Date)).TotalSeconds
        $host.UI.RawUI.CursorPosition = $origpos
        Write-Host "Waiting for $([math]::Ceiling($remaining)) seconds before next check..." -NoNewline
        Start-Sleep -Seconds 1
    }
}

## VPN is no longer connected, exit the script
Write-Output "VPN is no longer connected, script exiting..."
[system.media.systemsounds]::Exclamation.play()
Get-Process -Name "vpnui" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
exit 0
## END ###########################