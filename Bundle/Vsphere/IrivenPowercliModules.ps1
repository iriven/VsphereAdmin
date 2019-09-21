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
if(!$PSScriptRoot){ $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
try
{
    #. (Join-Path $PSScriptRoot 'Clusters\ClustersManagement.ps1')
   # . (Join-Path $PSScriptRoot 'Datastores\DatastoresManagement.ps1')
    #. (Join-Path $PSScriptRoot 'Folders\FoldersManagement.ps1') 
   # . (Join-Path $PSScriptRoot 'Hosts\HostsManagement.ps1')
    #. (Join-Path $PSScriptRoot 'Networks\NetworksManagement.ps1')
    #. (Join-Path $PSScriptRoot 'Resourcepool\ResourcepoolsManagement.ps1')
    #. (Join-Path $PSScriptRoot 'Templates\TemplatesManagement.ps1')
    #. (Join-Path $PSScriptRoot 'vApps\VCenterManagement.ps1')
    . (Join-Path $PSScriptRoot 'VCenter\vCenterManagement.ps1')    
    . (Join-Path $PSScriptRoot 'Virtualmachines\VirtualmachineManagement.ps1')
    #. (Join-Path $PSScriptRoot 'Vsan\vAppsManagement.ps1') 
}
catch
{
    write-error -Message $_.Exception.Message  -EA Stop
}