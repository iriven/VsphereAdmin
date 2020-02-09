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

    UpdateVMmemoryResevation()
    {
        if (-not([PSIrivenUtils]::PropertyExists($this.Settings,'Action'))){ $this.Settings.Set_Item('Action','set')}
        if (-not([PSIrivenUtils]::PropertyExists($this.Settings,'MemoryGB'))){ Throw "Parameter Error. The new VM memory size value is not given."}
        $Result = New-Object System.Collections.ArrayList
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $MemoryHotAdd = New-Object VMware.Vim.optionvalue
        $Total = $this.VMObject.count
        $counter = 0
        $this.VMObject | ForEach-Object{
            $VMView = (Get-View $_) 
            $MemoryBGBefore=$_.MemoryGB
            $VMName = $_.Name
            $PowerState = $_.PowerState        
            $VMHost = ($_.VMHost).Name        
            $Cluster = ($_.VMHost).Parent
            $PowerCycleNeeded=$false
            $vCenter = $_.Uid.Substring($_.Uid.IndexOf('@')+1).Split(":")[0]
            if($this.Settings.ShowProgress)
            {
                $counter++
                $Parameters = @{ Activity = "vCEnter $($vCenter): -- Updating Virtual Machine Memory size  -->";
                                 Status = "-- Querying VM: [{0} of {1}]" -f $($counter), $($Total);
                                 CurrentOperation = $_;
                                 PercentComplete = (($counter /  $Total) * 100) 
                               }     
                Write-Progress @Parameters
            }
            $MemoryHotAddEnabled = [PSIrivenUtils]::GetBoolean("$($VMView.Config.MemoryHotAddEnabled)") 
            if (-not($MemoryHotAddEnabled)) {
                $MemoryHotAdd.Key = "mem.hotadd"
                $MemoryHotAdd.Value = "true"
                $vmConfigSpec.extraconfig += $MemoryHotAdd
                $message = "Activating 'Memory Hot Add' Option to VM: $($_.Name)"
                [PSIrivenEvents]::DisplayMessage("$message", 'white', $true)
                [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
                 #$_.Extensiondata.ReconfigVM($vmConfigSpec)
                $vmView.ReconfigVM($vmConfigSpec)
                [PSIrivenEvents]::DisplayMessage("done!", "green")
                sleep -Seconds 3
                $PowerCycleNeeded = $true
            }
            if(($_.PowerState -match "On") -And ($PowerCycleNeeded -eq $true))
            {
                [PSIrivenEvents]::DisplayMessage("WARNING: The new setting will take effect after the next VM PowerCycle (Power Off/On) not GuestOS Reboot", 'yellow')
                [PSIrivenEvents]::DisplayMessage("WARNING: The VM Memory reservation was not modified !. Please PowerCycle the VM, and then re-run this script in order to change your VM Memory size", 'yellow')
                [PSIrivenUtils]::AddNewLine()
            }
            else
            {
                switch -regex ($this.Settings.Action)
                {
                    '^reduce'{
                        if(-not($PowerState -match "On")){
                            if( $this.Settings.MemoryGB -ge $MemoryBGBefore){ Throw "Parameter Error. The memory size to remove from VM $($VMName) can not be greater than it total memory size" } 
                            $NewMemoryGB = $MemoryBGBefore - $this.Settings.MemoryGB
                            set-vm -VM "$($VMName)" -MemoryGB "$($NewMemoryGB)" -Confirm:$false ; 
                        } else{
                            [PSIrivenEvents]::DisplayMessage("WARNING: The VM $($VMName) is now Powered On. Memory Hot-remove is not supported in VMware Vsphere", 'yellow')
                            [PSIrivenEvents]::DisplayMessage("Please Power Off de VM and re-run the script!", 'yellow')
                            [PSIrivenUtils]::AddNewLine()
                        }
                        break
                    }
                    '^add'{ 
                        $NewMemoryGB = $MemoryBGBefore + $this.Settings.MemoryGB
                        set-vm -VM "$($VMName)" -MemoryGB "$($NewMemoryGB)" -Confirm:$false ;  break }
                    default {
                        if( ($this.Settings.MemoryGB -ge $MemoryBGBefore) -And ($PowerState -match "On")){ 
                            [PSIrivenEvents]::DisplayMessage("WARNING: The desired Memory size is less than the current $($VMName) VM memory size. Memory Hot-reduce is not supported in VMware Vsphere", 'yellow')
                            [PSIrivenEvents]::DisplayMessage("Please Power Off the $($VMName) VM and re-run the script!", 'yellow')
                            [PSIrivenUtils]::AddNewLine()

                        } else{
                            Set-VM -VM "$($VMName)" -MemoryGB "$($this.Settings.MemoryGB)" -Confirm:$false ; 
                            sleep 1;
                        }
                        break 
                    } 
                }
            }
            $MemoryBGAfter=(Get-VM -Name "$($VMName)").MemoryGB
            $VmReport = New-Object -Type PSObject -Property ([ordered]@{
                Name = "$($VMName)"
                PowerState = "$($PowerState)"
                MemoryHotAddEnabled = "$($VMView.Config.MemoryHotAddEnabled)"       
                MemoryBefore = ([math]::Round($MemoryBGBefore,2)| % {$([double]$_).ToString()}) + ' GB'  
                MemoryAfter = ([math]::Round($MemoryBGAfter,2)| % {$([double]$_).ToString()}) + ' GB' 
                VMHost = "$($VMHost)"         
                Cluster = "$($Cluster)" 
            })
            $Result.Add($VmReport) | Out-Null
        }
         $Result| out-default 
        if($? -eq $true){
            [PSIrivenUtils]::AddNewLine()
            [PSIrivenEvents]::DisplayMessage('Job Successfully finished ', 'green')
            [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
            [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
            sleep -Seconds 1
            [PSIrivenEvents]::DisplayMessage("done!", "green")
            [PSIrivenUtils]::AddNewLine()
        }        
    }

    UpdateVMCPUResevation()
    {
        if (-not([PSIrivenUtils]::PropertyExists($this.Settings,'Action'))){ $this.Settings.Set_Item('Action','set')}
        if (-not([PSIrivenUtils]::PropertyExists($this.Settings,'NumCpu'))){ Throw "Parameter Error. The new VM Total vCPU value is not given."}
        $Result = New-Object System.Collections.ArrayList
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $vCPUHotAdd = New-Object VMware.Vim.optionvalue
        $Total = $this.VMObject.count
        $counter = 0        
        $this.VMObject | ForEach-Object{
            $VMView = (Get-View $_) 
            $TotalCPUBefore=$_.NumCpu
            $VMName = $_.Name
            $PowerState = $_.PowerState        
            $VMHost = ($_.VMHost).Name        
            $Cluster = ($_.VMHost).Parent
            $PowerCycleNeeded=$false
            if($this.Settings.ShowProgress)
            {
                $counter++
                $Parameters = @{ Activity = "vCEnter $($vCenter): -- Updating Virtual Machine Memory size  -->";
                                 Status = "-- Querying VM: [{0} of {1}]" -f $($counter), $($Total);
                                 CurrentOperation = $_;
                                 PercentComplete = (($counter /  $Total) * 100) 
                               }     
                Write-Progress @Parameters
            }
            $CpuHotAddEnabled = [PSIrivenUtils]::GetBoolean("$($VMView.Config.CpuHotAddEnabled)") 
            if (-not($CpuHotAddEnabled)) {
                $vCPUHotAdd.Key = "vcpu.hotadd"
                $vCPUHotAdd.Value = "true"
                $vmConfigSpec.extraconfig += $vCPUHotAdd
                $message = "Activating 'vCPU Hot Add' Option to VM: $($_.Name)"
                [PSIrivenEvents]::DisplayMessage("$message", 'white', $true)
                [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
                 #$_.Extensiondata.ReconfigVM($vmConfigSpec)
                $vmView.ReconfigVM($vmConfigSpec)
                [PSIrivenEvents]::DisplayMessage("done!", "green")
                sleep -Seconds 3
                $PowerCycleNeeded = $true
            }
            if(($_.PowerState -match "On") -And ($PowerCycleNeeded -eq $true))
            {
                [PSIrivenEvents]::DisplayMessage("WARNING: The new setting will take effect after the next VM PowerCycle (Power Off/On)", 'yellow')
                [PSIrivenEvents]::DisplayMessage("When done, re-run this script in order to change your VM vCPU reservation", 'yellow')
                [PSIrivenUtils]::AddNewLine()
            }
            else
            {
                switch -regex ($this.Settings.Action)
                {
                    '^reduce'{
                        if(-not($PowerState -match "On")){
                            if( $this.Settings.NumCpu -ge $TotalCPUBefore){ Throw "Parameter Error. The Total vCPU to remove from VM $($VMName) can not be greater than it maximum vCPU" } 
                            $NewNumCpu = $TotalCPUBefore - $this.Settings.NumCpu
                            set-vm -VM "$($VMName)" -NumCpu "$($NewNumCpu)" -Confirm:$false ; 
                        } else{
                            [PSIrivenEvents]::DisplayMessage("WARNING: The VM $($VMName) is now Powered On. vCPU Hot-remove is not supported in VMware Vsphere", 'yellow')
                            [PSIrivenEvents]::DisplayMessage("Please Power Off de VM and re-run the script!", 'yellow')
                            [PSIrivenUtils]::AddNewLine()
                        }
                        break
                    }
                    '^add'{ 
                        $NewNumCpu = $TotalCPUBefore + $this.Settings.NumCpu
                        set-vm -VM "$($VMName)" -NumCpu "$($NewNumCpu)" -Confirm:$false ;  break }
                    default {
                        Set-VM -VM "$($VMName)" -NumCpu "$($this.Settings.NumCpu)" -Confirm:$false ; 
                        sleep 3; 
                        break 
                    } 
                }
            }
            $TotalCPUAfter=(Get-VM -Name "$($VMName)").NumCpu
            $VmReport = New-Object -Type PSObject -Property ([ordered]@{
                Name = "$($VMName)"
                PowerState = "$($PowerState)"
                CpuHotAddEnabled = "$($VMView.Config.CpuHotAddEnabled)"       
                vCPUBefore = ([math]::Round($TotalCPUBefore,2)| % {$([double]$_).ToString()}) 
                vCPUAfter = ([math]::Round($TotalCPUAfter,2)| % {$([double]$_).ToString()})
                VMHost = "$($VMHost)"         
                Cluster = "$($Cluster)" 
            })
            $Result.Add($VmReport) | Out-Null
        }
         $Result| out-default 
        if($? -eq $true){
            [PSIrivenUtils]::AddNewLine()
            [PSIrivenEvents]::DisplayMessage('Job Successfully finished ', 'green')
            [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
            [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
            sleep -Seconds 1
            [PSIrivenEvents]::DisplayMessage("done!", "green")
            [PSIrivenUtils]::AddNewLine()
        }        
    }


    
}