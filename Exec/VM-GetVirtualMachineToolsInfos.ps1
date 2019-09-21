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
        Position=0)]$VMs,                 
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

    if(-not([PSIrivenVISession]::isStarted()))
    {
        $ConfigInstance.Parse('Sessions')
        $VCSession = [PSIrivenVISession]::New($ConfigInstance.GetParams())
        $VCSession.Start()
    }
    if(-not($VMs)) { $VMs = (Get-VM)}
    if($VMs -is [system.String]) { $VMs = (Get-VM "$VMs")}
    $VMs = $($VMs| ? {$_.pstypenames -contains "VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl"})
    if (-not $VMs){ Throw "No Virtual Machine found.`nIs ""$VMs"" a VM Object ?" }  
    $ConfigInstance.Parse('Outputs')
    $Config = $ConfigInstance.GetParams()
    $Config.Set_Item('OutputsDirectory', $OutputsDirectory)
    $VirtualMachine = [PSIrivenVMInfos]::New($VMs,$Config)
    $VirtualMachine.GetToolsInfo()
    if($AutoLogout -eq $true){[PSIrivenVISession]::Close() }
}
catch [Exception]{
  write-error -Message $_.Exception.Message  -EA Stop
}

