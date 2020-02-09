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
        ValueFromPipeline=$false,                            
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
    #if(-not($VMs)) { $VMs = (Get-VM)}
    #if(-not($VMs)) { $VMs = (get-cluster "*wup*"|where-object{$_.Name -Match "wup"}|Get-VM)}
    if(-not($VMs)) { $VMs = (Get-VM)}
    if($VMs -is [system.String]) { $VMs = (Get-VM "$VMs")}
    $VMs = $($VMs| ? {$_.pstypenames -contains "VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl"})
    if (-not $VMs){ Throw "No Virtual Machine found.`nIs ""$VMs"" a VM Object ?" }  
    $ConfigInstance.Parse('Outputs')
    $Config = $ConfigInstance.GetParams()
    $Config.Set_Item('OutputsDirectory', $OutputsDirectory)
    $VirtualMachine = [PSIrivenVMInfos]::New($VMs,$Config)
    $VirtualMachine.GetHotPlugOptionsInfos()
    if($AutoLogout -eq $true){[PSIrivenVISession]::Close() }
}
catch [Exception]{
  write-error -Message $_.Exception.Message  -EA Stop
}