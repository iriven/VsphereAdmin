<# Header_start
#################################################################################
#                                                                               #
#   Module PowerShell / Powercli Pour Administration Infra virtualisée VMware   #
#                                                                               #
# ----------------------------------------------------------------------------- #
#   Author: Alfred TCHONDJO - Iriven France    (POUR ORANGE)                    #
#   Date: 2019-02-08                                                            #
# ----------------------------------------------------------------------------- #
#   Revisions                                                                   #
#                                                                               #
#   G1R0C0 :    Creation du script le 08/02/2019 (AT)                           #
#                                                                               #
#################################################################################
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
    $Cluster = $($Cluster| where-object {$_.pstypenames -contains "VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl"})
    if (-not $Cluster){ Throw "No Cluster found.`nIs ""$Cluster"" a Vsphere Cluster Object ?" }  
    $ConfigInstance.Parse('Outputs')
    $Config = $ConfigInstance.GetParams()
    $Config.Set_Item('OutputsDirectory', $OutputsDirectory)
    #$VirtualMachine = [PSIrivenVMInfos]::New($Cluster,$Config)
    #$VirtualMachine.GetNetworkReport()


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



