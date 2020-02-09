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
class PSIrivenDatastoreInfos{

    [ValidateNotNullOrEmpty()]
    [HashTable]
    hidden $Settings;

    [ValidateNotNullOrEmpty()]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]
    hidden $DSObject;

    PSIrivenDatastoreInfos([VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$VMs,[HashTable]$Config)
    {
        try {
            if (-not([PSIrivenUtils]::PropertyExists($Config,'DisplayMode')) -or ($Config.DisplayMode.get_Count() -eq 0)) 
            {
                throw "Error: Can't initialize PSIrivenDatastoreInfos Class; Invalid Configuration Data Given."
            }
            if(-not([PSIrivenUtils]::PropertyExists($Config,'OutputsDirectory')))
            {$Config.Set_Item('OutputsDirectory',(Split-Path $MyInvocation.MyCommand.Path -Parent))}
            if(-not([PSIrivenUtils]::PropertyExists($Config,'ShowProgress'))){$Config.Set_Item('ShowProgress','True')}
            
            $Config.Set_Item('ShowProgress',[PSIrivenUtils]::GetBoolean($Config.ShowProgress))
            $this.Settings += $Config
            #$this.VMObject += $VMs
             $this.VMObject = $VMs | ? {$_.pstypenames -contains "VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl"}
            if (-not($this.VMObject)){
                Throw "No Virtual Machine found.`nIs ""$VMs"" a VM Object?"
            }
        }
        catch [Exception]{
                write-error -Message $_.Exception.Message  -EA Stop
        }
    }


}    




function Get-VmfsDatastoreInfo
{
	[CmdletBinding(SupportsShouldProcess = $True)]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $True)]
		[PSObject]$Datastore
	)
	
	Process
	{
		if ($Datastore -is [String])
		{
			$Datastore = Get-Datastore -Name $Datastore -ErrorAction SilentlyContinue
		}
		if ($Datastore -isnot [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.Datastore])
		{
			Write-Error 'Invalid value for Datastore.'
			return
		}
		if ($Datastore.Type -ne 'VMFS')
		{
			Write-Error "$($Datastore.Name) is not a VMFS datastore"
			return
		}
		
		# Get the Datastore System Manager from an ESXi that has the Datastore
		$esx = Get-View -Id ($Datastore.ExtensionData.Host | Get-Random | Select -ExpandProperty Key)
		$hsSys = Get-View -Id $esx.ConfigManager.StorageSystem
		
		foreach ($extent in $Datastore.ExtensionData.Info.Vmfs.Extent)
		{
			$lun = $esx.Config.StorageDevice.ScsiLun | where{ $_.CanonicalName -eq $extent.DiskName }
			
			$hdPartInfo = $hsSys.RetrieveDiskPartitionInfo($lun.DeviceName)
			$hdPartInfo[0].Layout.Partition | %{
				New-Object PSObject -Property ([ordered]@{
						Datastore = $Datastore.Name
						CanonicalName = $lun.CanonicalName
						Model = "$($lun.Vendor.TrimEnd(' ')).$($lun.Model.TrimEnd(' ')).$($lun.Revision.TrimEnd(' '))"
						DiskSizeGB = $hdPartInfo[0].Layout.Total.BlockSize * $hdPartInfo[0].Layout.Total.Block / 1GB
						DiskBlocks = $hdPartInfo[0].Layout.Total.Block
						DiskBlockMB = $hdPartInfo[0].Layout.Total.BlockSize/1MB
						PartitionFormat = $hdPartInfo[0].Spec.PartitionFormat
						Partition = if ($_.Partition -eq '') { '<free>' }else{ $_.Partition }
						Used = $extent.Partition -eq $_.Partition
						Type = $_.Type
						PartitionSizeGB = [math]::Round(($_.End.Block - $_.Start.Block + 1) * $_.Start.BlockSize / 1GB, 1)
						PartitionBlocks = $_.End.Block - $_.Start.Block + 1
						PartitionBlockMB = $_.Start.BlockSize/1MB
						Start = $_.Start.Block
						End = $_.End.Block
					})
			}
		}
	}
}