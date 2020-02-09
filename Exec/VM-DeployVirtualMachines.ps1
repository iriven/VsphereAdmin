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
 	$ConfigInstance.Parse('VmDeployement')
    $ConfigInstance.Parse('Outputs')
    $Config = $ConfigInstance.GetParams()
    $Config.Set_Item('OutputsDirectory', $OutputsDirectory)
    $VmDeployement = [PSIrivenVMDeploy]::New($Config)


    #$VirtualMachine.GetStats()
    if($AutoLogout -eq $true){[PSIrivenVISession]::Close() }
}
catch [Exception]{
  write-error -Message $_.Exception.Message  -EA Stop
}



#region: Create Options
	$ExtraOptions = @{
		"isolation.tools.diskShrink.disable"="true";
		"isolation.tools.diskWiper.disable"="true";
		"isolation.tools.copy.disable"="true";
		"isolation.tools.paste.disable"="true";
		"isolation.tools.dnd.disable"="true";
		"isolation.tools.setGUIOptions.enable"="false"; 
		"log.keepOld"="10";
		"log.rotateSize"="100000"
		"RemoteDisplay.maxConnections"="2";
		"RemoteDisplay.vnc.enabled"="false";  
	
	}
    if ($DebugPreference -eq "Inquire") {
        Write-Output "VM Hardening Options:"
        $ExtraOptions | Format-Table -AutoSize
    }
	
	$VMConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
	
	Foreach ($Option in $ExtraOptions.GetEnumerator()) {
		$OptionValue = New-Object VMware.Vim.optionvalue
		$OptionValue.Key = $Option.Key
		$OptionValue.Value = $Option.Value
		$VMConfigSpec.extraconfig += $OptionValue
	}
#endregion

#region: Apply Options
	ForEach ($VM in $VMs){
			$VMv = Get-VM $VM | Get-View
		$state = $VMv.Summary.Runtime.PowerState
		Write-Output "...Starting Reconfiguring VM: $VM "
		$TaskConf = ($VMv).ReconfigVM_Task($VMConfigSpec)
			if ($state -eq "poweredOn") {
				Write-Output "...Migrating VM: $VM "
				$TaskMig = $VMv.MigrateVM_Task($null, $_.Runtime.Host, 'highPriority', $null)
				}
		}
	}
#endregion
#https://github.com/vmware/PowerCLI-Example-Scripts/blob/master/Modules/apply-hardening/apply-hardening.psm1