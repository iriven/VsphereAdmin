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