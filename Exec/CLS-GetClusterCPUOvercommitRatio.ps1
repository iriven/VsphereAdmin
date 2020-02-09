<# Header_start
################################################################################################
#                                                                                              #
#  Author:         Alfred TCHONDJO - (Iriven France)   Pour Orange                             #
#  Date:           2020-02-04                                                                  #
#  Website:        https://github.com/iriven?tab=repositories                                  #
#                                                                                              #
# -------------------------------------------------------------------------------------------- #
#                                                                                              #
#  Project:        PowerShell / Powercli Framework                                             #
#  Description:	   A class based PowerShell/Powercli librairy to manage VMware Infrastructure  #
#  Version:        1.0.0    (G1R0C0)                                                           #
#                                                                                              #
#  License:		   GNU GPLv3                                                                   #
#                                                                                              #
#  This program is free software: you can redistribute it and/or modify                        #
#  it under the terms of the GNU General Public License as published by                        #
#  the Free Software Foundation, either version 3 of the License, or                           #
#  (at your option) any later version.                                                         #
#                                                                                              #
#  This program is distributed in the hope that it will be useful,                             #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of                              #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                               #
#  GNU General Public License for more details.                                                #
#                                                                                              #
#  You should have received a copy of the GNU General Public License                           #
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.                       #
#                                                                                              #
# -------------------------------------------------------------------------------------------- #
#  Revisions                                                                                   #
#                                                                                              #
#  - G1R0C0 :        Creation du script le 04/02/2020 (AT)                                     #
#  - G1R0C1 :        MAJ - Modification VM Memory Size le 04/02/2020 (AT)                      #
#                                                                                              #
################################################################################################
# Header_end
#>
[CmdletBinding()]
param( 
    [Parameter(Mandatory=$false,                            
        ValueFromPipeline=$True,                            
        Position=0)]$Cluster,                 
    [Parameter(Mandatory=$false,                           
        ValueFromPipeline=$true,                            
        Position=1)]
    [bool]$AutoLogout=$false  
)
if(!$PSScriptRoot){ $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
$BaseDirectory = Split-Path $PSScriptRoot -Parent
$SrcDirectory = (Join-Path $BaseDirectory 'Bundle')
$ConfigDirectory = (Join-Path $BaseDirectory 'Config')
$OutputsDirectory = (Join-Path $BaseDirectory 'Outputs')
$IrivenClassmap = 'IrivenVsphereAdminBundle.ps1'
try {
    . (Join-Path $SrcDirectory $IrivenClassmap)
    $ConfigInstance = [PSIrivenConfig]::New($ConfigDirectory)
    $Cluster="CLAVDRSIDPMS01"
    if(-not([PSIrivenVISession]::isStarted()))
    {
        $ConfigInstance.Parse('Sessions')
        $VCSession = [PSIrivenVISession]::New($ConfigInstance.GetParams())
        $VCSession.Start()
    }
    if(-not($Cluster)) { $Cluster = (Get-Cluster)}
    if($Cluster -is [system.String]) { $Cluster = (Get-Cluster "*$Cluster*")}
    $Cluster = $($Cluster| where-object {$_.pstypenames -contains "VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl"})
    if (-not $Cluster){ Throw "No Cluster found.`nIs ""$Cluster"" a Vsphere Cluster Object ?" }  
    $ConfigInstance.Parse('Outputs')
    $Config = $ConfigInstance.GetParams()
    $Config.Set_Item('OutputsDirectory', $OutputsDirectory)
    #$ClusterObject = [PSIrivenCLSInfos]::New($Cluster,$Config)
    #$ClusterObject.GetNetworkReport()


#https://www.virtualease.fr/powercli-script-contention-overcommit
#param($vmhosts="*")

#$vmhosts=Get-Cluster $Cluster|Get-VMHost
#$Cluster=Get-Cluster $Cluster|Get-VM|where {$_.PowerState -eq "PoweredOn"}
$cvalue = New-Object psobject

$Output=@()
$Output1=@()
$totalvcpus=0
$totalhostthreads=0
$totalratio=0
Get-Cluster $Cluster|Get-VMHost|Foreach-Object{
	$vCPUCount=0
    $Ratio=$null
    $Multiple=1
    $hyperthreadingActive=$_.HyperThreadingActive
    if($hyperthreadingActive -eq "True"){ $Multiple="0.75"}
    $VMhostThreads=($_.extensiondata.hardware.cpuinfo.numcputhreads * $Multiple)
    Get-VMHost $_.Name|Get-VM|Foreach-Object{$vCPUCount+=$_.numcpu}
    if($vCPUCount -ne "0"){ $Ratio =("{0:N1}" -f ($vCPUCount / $VMhostThreads))}

	$hvalue=New-Object psobject
	$hvalue|Add-Member -MemberType Noteproperty "Hostname" -value $_.name
	$hvalue|Add-Member -MemberType Noteproperty "pCPU Available" -Value "$VMhostThreads"
	$hvalue|Add-Member -MemberType Noteproperty "vCPU Consummed" -Value "$vCPUCount"
    $hvalue|Add-Member -MemberType Noteproperty "pCPU Ratio" -Value "$Ratio"
    $hvalue|Add-Member -MemberType Noteproperty "HyperThreading" -Value "$hyperthreadingActive"
	$Output+=$hvalue
	$totalhostthreads += "$VMhostThreads"
	$totalvcpus += "$vCPUCount"
	$totalratio=$("{0:N1}" -f ($totalvcpus / $totalhostthreads))    

}
$cvalue|Add-Member -MemberType Noteproperty "Cluster" -value "$Cluster"
$cvalue|Add-Member -MemberType Noteproperty "pCPU Available" -Value "$totalhostthreads"
$cvalue|Add-Member -MemberType Noteproperty "vCPU Consummed" -Value "$totalvcpus"
$cvalue|Add-Member -MemberType Noteproperty "pCPU Ratio" -Value "$totalratio"
$Output1 += $cvalue
$Output|ft -autosize
$Output1|ft -autosize

#Get-VMHost | Select-Object Name,HyperthreadingActive
#Get-Cluster "CLOAUBSIDWIS04"|Get-VMHost|foreach-object {$_.name; $_.extensiondata.hardware.cpuinfo}|ft


    if($AutoLogout -eq $true){[PSIrivenVISession]::Close() }
}
catch [Exception]{
  write-error -Message $_.Exception.Message  -EA Stop
}



