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
class PSIrivenVMEditor{

    [ValidateNotNullOrEmpty()]
    [HashTable]
    hidden $Settings;

    [ValidateNotNullOrEmpty()]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]
    hidden $VMObject;

    PSIrivenVMEditor([VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$VMs,[HashTable]$Config)
    {
        try {
            if (-not([PSIrivenUtils]::PropertyExists($Config,'DisplayMode')) -or ($Config.DisplayMode.get_Count() -eq 0)) 
            {
                throw "Error: Can't initialize PSIrivenVMEditor Class; Invalid Configuration Data Given."
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
     CreateSnapshot()
    {
        $this.VMObject | where {($_.PowerState -match "On") -And ($_.ExtensionData.Guest.ToolsStatus -NotLike "*NotInstalled")}  |ForEach-Object{
            $SnapshotName = 'Snapshot_'+ $($_.Name) + '_' + $(Get-Date -Format 'MM-dd-yyyy-HHmmss');
            $message = 'Creating New Snapshot for VM: ' + $($_.Name) + ' with name: ' + $SnapshotName
            [PSIrivenEvents]::DisplayMessage("$message",'white')
            $process = Get-Vm "$($_.Name)"| new-snapshot -name $SnapshotName -Description "Created on $(Get-Date)" -RunAsync
            while('Success','Error' -notcontains $process.State){
                sleep 2
                $process = Get-Task -Id $process.Id
            }
            $color = 'green'
            if($($process.State) -Notmatch 'Success'){$color = 'yellow'}
            [PSIrivenEvents]::DisplayMessage("CreateSnapshot completed with $($process.State)", "$color ")
            [PSIrivenUtils]::AddNewLine()
        } #end foreach Object
    } # end funct


    RemoveSnapshot(){
        if(-not([PSIrivenUtils]::PropertyExists($this.Settings,'MinAge'))){$this.Settings.Set_Item('MinAge','3')}
        $this.VMObject | where {($_.PowerState -match "On") -And ($_.ExtensionData.Guest.ToolsStatus -NotLike "*NotInstalled")} | ForEach-Object{
            $days="-$($this.Settings.MinAge)"
            $snapshot =(Get-VM -Name $_.Name| Get-Snapshot | Where {$_.Created -lt (Get-Date).AddDays($days)})
            $SnapshotMeasure = ($snapshot | Measure-Object)
            if ($SnapshotMeasure.Count -gt 0) {
                $message = " Removing " + ($SnapshotMeasure.Count).ToString() +" Snapshot(s) for VM $($_.Name)"
                [PSIrivenEvents]::DisplayMessage("$message",'white', $true)
                $snapshot | Remove-Snapshot -Confirm:$false
               # $t = Get-VM MyVM | Get-Snapshot -Name MySnap | Remove-Snapshot -RunAsync -Confirm:$false
                if($? -eq $true){ 
                    [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
                    [PSIrivenEvents]::DisplayMessage("OK", "green")
                    [PSIrivenEvents]::DisplayMessage("All Snapshots removed for $($_.Name)") 
                     [PSIrivenUtils]::AddNewLine()
                }
            }
        }
   }

   SetToolsUpgradePolicy([String]$UpgradePolicy)
   {
        if(-not(('UpgradeAtPowerCycle', 'manual')  -contains "$UpgradePolicy")) { $UpgradePolicy = 'UpgradeAtPowerCycle' }
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
        $vmConfigSpec.Tools.ToolsUpgradePolicy = $UpgradePolicy
        $this.VMObject | where {$_.ExtensionData.Guest.ToolsStatus -ne 'toolsOk'}|ForEach-Object{
            $vmView = (Get-View $_.Name -Property Config.Tools.ToolsUpgradePolicy)
            if ($vmView.Config.Tools.ToolsUpgradePolicy -ne $UpgradePolicy) {
               $message = "Applying 'upgradeAtPowerCycle' setting to VM: $($_.Name)"
               [PSIrivenEvents]::DisplayMessage("$message", 'white', $true)
               [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
               $vmView.ReconfigVM($vmConfigSpec)
               [PSIrivenEvents]::DisplayMessage("done!", "green")
               [PSIrivenUtils]::AddNewLine()
               Get-VMToolsUpgradePolicy -VM $($_.Name)
           }
        }
        if($? -eq $true){
            [PSIrivenUtils]::AddNewLine()
            [PSIrivenEvents]::DisplayMessage('Job Successfully finished ', 'green')
            [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
            [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
            sleep 1
            [PSIrivenEvents]::DisplayMessage("done!", "green")
            [PSIrivenUtils]::AddNewLine()
        }        
   }





}