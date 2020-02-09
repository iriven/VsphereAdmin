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
class PSIrivenVMInfos{

    [ValidateNotNullOrEmpty()][HashTable]
    hidden $Settings;
    
    [ValidateNotNullOrEmpty()]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]
    hidden $VMObject;

    PSIrivenVMInfos([VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$VMs,[HashTable]$Config)
    {
        try {
            if (-not([PSIrivenUtils]::PropertyExists($Config,'DisplayMode')) -or ($Config.DisplayMode.get_Count() -eq 0)) 
            {
                throw "Error: Can't initialize PSIrivenVMInfos Class; Invalid Configuration Data Given."
            }
            if(-not([PSIrivenUtils]::PropertyExists($Config,'OutputsDirectory')))
            {$Config.Set_Item('OutputsDirectory',(Split-Path $MyInvocation.MyCommand.Path -Parent))}
            if(-not([PSIrivenUtils]::PropertyExists($Config,'ShowProgress'))){$Config.Set_Item('ShowProgress','True')}
            
            $Config.Set_Item('ShowProgress',[PSIrivenUtils]::GetBoolean($Config.ShowProgress))
            $this.Settings += $Config
            #$this.VMObject += $VMs
             $this.VMObject = $VMs | ? {$_.pstypenames -contains "VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl"}
            if (-not $this.VMObject){
                Throw "No Virtual Machine found.`nIs ""$VMs"" a VM Object?"
            }
        }
        catch [Exception]{
            write-error -Message $_.Exception.Message  -EA Stop
        }
    }

   GetReport()
    {
        $MenusItems = ( $this.Settings.DisplayMode.GetEnumerator()| ForEach-Object{$_.Name}| sort-object)
        [String]$OutputMode = $([PSIrivenMenu]::Generate($MenusItems, "PLEASE CHOOSE THE DESIRED OUTPUT DESTINATION"))
        if (-not($OutputMode))
        {
          [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
          [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
          sleep 1
          [PSIrivenEvents]::DisplayMessage("done!", "green")
          [PSIrivenUtils]::AddNewLine()
          Exit
        }
        $Result = New-Object System.Collections.ArrayList
        $Total = $this.VMObject.count
        $start = (Get-Date).AddDays(-30)
        $finish = Get-Date
        $counter = 0
        $this.VMObject | where {$_.PowerState -match "On" -And $_.ExtensionData.Guest.ToolsStatus -NotLike "*NotInstalled"} |ForEach-Object{
            if([Object]::ReferenceEquals((Get-NetworkAdapter -VM $_.Name), $NULL)){continue; $Total--;}
            if(($_.Guest.Nics).Count -eq 0){continue;}
            $vCenter = $_.Uid.Substring($_.Uid.IndexOf('@')+1).Split(":")[0]
            if($this.Settings.ShowProgress)
            {
                $counter++
                $Parameters = @{ Activity = "vCEnter $($vCenter): -- Retrieving Virtual Machine Informations  -->";
                                 Status = "-- Querying VM: [{0} of {1}]" -f $($counter), $($Total);
                                 CurrentOperation = $_;
                                 PercentComplete = (($counter /  $Total) * 100) 
                               }     
                Write-Progress @Parameters
            }                
            $VmIpStack = ($_.ExtensionData.Guest.IpStack)
            $VmRoutes = ($VmIpStack.IpRouteConfig.IpRoute)
            $Gateway = ($VmRoutes.Gateway.IpAddress | where {$_ -ne $null}| select -uniq)
            $NetworkAdapters = (Get-NetworkAdapter -Vm $_.Name)
            $NicType = ($NetworkAdapters| Select -ExpandProperty Type| select -uniq)
            if (-not($Gateway)) { $Gateway = '-' }
            if (-not($NicType)) { $NicType = '-' }
            $VmGuest = Get-VMGuest  -VM $_.Name
            $Network = New-Object -TypeName System.Collections.Generic.List[String]
            $VmRoutes|foreach-object{
                if (($VmGuest.IPAddress -replace "[0-9]$|[1-9][0-9]$|1[0-9][0-9]$|2[0-4][0-9]$|25[0-5]$", "0" | select -uniq) -contains $_.Network) {
                    $Network.Add($_.Network + '/' + $_.PrefixLength) | Out-Null
                }
            }
            $QuickStats = get-stat -Entity $_.Name -Stat "cpu.usage.average","mem.usage.average","net.usage.average" -IntervalMins 5 -Start $start -Finish $finish
            $VmReport = New-Object -Type PSObject -Property ([ordered]@{
                Name = $_.Name
                FQDN = $_.Guest.HostName;
                PowerState = $_.PowerState
                CpuCount = $_.NumCpu
                CoresPerSocket = $_.CoresPerSocket
                Memory = ([math]::round($_.MemoryGB, 2) | % {$([double]$_).ToString()}) + ' GB'
                AvgMemoryUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "mem.usage.average"} | Measure-Object -Property Value -Average).Average) + ' %'
                MaxMemoryUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "mem.usage.average"} | Measure-Object -Property Value -Maximum).Maximum) + ' %'
                AvgCPUUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "cpu.usage.average"} | Measure-Object -Property Value -Average).Average) + ' %'
                MaxCPUUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "cpu.usage.average"} | Measure-Object -Property Value -Maximum).Maximum) + ' %'
                AvgNetworkUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "net.usage.average"} | Measure-Object -Property Value -Average).Average) + ' KBs'
                MaxNetworkUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "net.usage.average"} | Measure-Object -Property Value -Maximum).Maximum) + ' KBs'
                ToolsStatus = $_.Guest.State
                GuestId = $_.GuestId
                DrsAutomationLevel = $_.DrsAutomationLevel
                Uid = $_.Uid
                VmId = $_.Id
                ShowProgressId = $_.ShowProgressId
                VMHost = ($_.VMHost).Name           
                VMHostId = $_.VMHostId
                Cluster = ($_.VMHost).Parent
                VCenter = $vCenter
                PortGroup = [system.String]::Join(', ', $NetworkAdapters.NetworkName)
                IPAddress = [system.String]::Join(', ', $_.Guest.IPAddress)
                SubnetMask = [system.String]::Join(', ', "$Network")
                MacAddress = [system.String]::Join(', ', ($NetworkAdapters|Select -ExpandProperty MacAddress )) #($NetworkAdapters|Select -ExpandProperty MacAddress ) -join ' , '
                Gateway = [system.String]::Join(', ', $Gateway)
                TotalNics = ($_.Guest.Nics).Count                    
                NicType = [system.String]::Join(', ', $NicType)
                DNS =  $VmIpStack.DnsConfig.IpAddress
                OS = $_.Guest.OSFullName
                DiskProvisioned = ([math]::Round($_.ProvisionedSpaceGB,2)| % {$([double]$_).ToString()}) + ' GB'
                DiskUsedSpace = ([math]::Round($_.UsedSpaceGB,2)| % {$([double]$_).ToString()}) + ' GB'
                DatastoreIdList = $_.DatastoreIdList 
                ResourcePool = ($_.ResourcePool).Name
                ResourcePoolId = $_.ResourcePoolId
                HeartbeatStatus = $_.ExtensionData.GuestHeartbeatStatus
                ConfigStatus =  $_.ExtensionData.ConfigStatus
                ConfigIssue =  $_.ExtensionData.ConfigIssue
                OverallStatus =  $_.ExtensionData.OverallStatus
                ToolsVersion = $_.Version
                Folder = $_.Folder.Name
                FolderId = $_.FolderId                    
                CustomFields = $_.CustomFields
               # Notes = $_.Notes
            })
            $Result.Add($VmReport) | Out-Null
            if(-not($this.Settings.ShowProgress)) {$VmReport}
            }
            if($this.Settings.ShowProgress) { Write-Progress -Activity "Completed" -Completed ;} 
            if(-not([PSIrivenUtils]::PathExists($this.Settings.OutputsDirectory)))
            {[PSIrivenUtils]::MakeDirectory($this.Settings.OutputsDirectory)}
            $OutputFile = (Join-Path $this.Settings.OutputsDirectory $((Get-Datacenter| Select-Object -first 1 -ExpandProperty Name) + '_VirtualmachineReports'))
            switch -regex ($OutputMode)
            {
                '^Csv'{
                    $OutputFile += '.csv'
                    $Result|Export-Csv $OutputFile -NoTypeInformation -ErrorAction Stop; 
                    break
                }
                '^Text'{
                    $OutputFile += '.txt'
                    $Result|Out-File  -FilePath $OutputFile -Force; 
                    break
                }
                '^ISE'{ $Result|out-gridview; break }
                default { $Result| out-default ;  break} 
            }
            if($? -eq $true){
                [PSIrivenEvents]::DisplayMessage('Job Successfully finished ', 'green')
                [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
                [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
                sleep 1
                [PSIrivenEvents]::DisplayMessage("done!", "green")
                [PSIrivenUtils]::AddNewLine()
            }

           # return $Result
    } # END GetReport


   # [PSCustomObject]HasSnapshots(){}
   
    GetSnapshotReport(){
        $MenusItems = ( $this.Settings.DisplayMode.GetEnumerator()| ForEach-Object{$_.Name}| sort-object)
        [String]$OutputMode = $([PSIrivenMenu]::Generate($MenusItems, "PLEASE CHOOSE THE DESIRED OUTPUT DESTINATION"))
        if (-not($OutputMode))
        {
          [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
          [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
          sleep 1
          [PSIrivenEvents]::DisplayMessage("done!", "green")
          [PSIrivenUtils]::AddNewLine()
          Exit
        }
        $Result = New-Object System.Collections.ArrayList
        $Total = $this.VMObject.count
        $VmCounter = 0
        $this.VMObject | where {($_.PowerState -match "On") -And ($_.ExtensionData.Guest.ToolsStatus -NotLike "*NotInstalled")} |ForEach-Object{
            if($this.Settings.ShowProgress)
            {
                $VmCounter++
                $Parameters = @{ Activity = "Verifying the existence of a Virtual Machine Snapshot -->";
                                 Status = "vCEnter $($vCenter) -- Querying VM: $($VmCounter) of $($Total)";
                                 CurrentOperation = $_;
                                 PercentComplete = (($VmCounter /  $Total) * 100) 
                               }     
                Write-Progress @Parameters
            } 
            $vmItem = $_.Name
            $vCenter = $_.Uid.Substring($_.Uid.IndexOf('@')+1).Split(":")[0]
            $snapshot =(Get-Snapshot -VM $vmItem)
            $SnapshotMeasure = ($snapshot | Measure-Object)
            if($SnapshotMeasure.Count -gt 0) {
                $SnapTotal = $SnapshotMeasure.Count
                $SnapCounter = 0
                $snapshot | ForEach-Object{
                
                    if($this.Settings.ShowProgress)
                    {
                        $SnapCounter++
                        $SnapParameters = @{ Activity = "Retrieving VM Snapshot Report -->";
                                         Status = "Virtual Machine $($vmItem) -- Querying snapshot: $($SnapCounter) of $($SnapTotal)";
                                         CurrentOperation = $_;
                                         PercentComplete = (($SnapCounter /  $SnapTotal) * 100) 
                                       }     
                        Write-Progress @SnapParameters
                    }
                    $snapshotSizeGB = ([Math]::Round( $_.SizeGB,       2 )).ToString() + ' GB';
                    $snapshotAgeDays = (((Get-Date) - $_.Created).Days).ToString() + ' Jours';
                    $SnapsReport = New-Object -Type PSObject -Property ([ordered]@{
                        Snapshot = $_.Name;
                        VmName = $vmItem
                        PowerState = $_.PowerState
                        CreationDate = $_.Created
                        AgeDays = $snapshotAgeDays;
                        ParentSnapshot = $_.ParentSnapshot.Name
                        IsCurrentSnapshot = $_.IsCurrent;
                        SnapshotSizeGB = $snapshotSizeGB
                        Description = $_.Description
                    })
                    $Result.Add($SnapsReport) | Out-Null
                    if(-not($this.Settings.ShowProgress)) {$SnapsReport}
                } #End ForEach-Object  $snapshot
            } # end $SnapshotMeasure.Count
        } #End ForEach-Object
        if($this.Settings.ShowProgress) { Write-Progress -Activity "Completed" -Completed ;} 
        if(-not([PSIrivenUtils]::PathExists($this.Settings.OutputsDirectory)))
        {[PSIrivenUtils]::MakeDirectory($this.Settings.OutputsDirectory)}
        $OutputFile = (Join-Path $this.Settings.OutputsDirectory $((Get-Datacenter|select -ExpandProperty Name) + '_SnapshotReports'))
        switch -regex ($OutputMode)
        {
            '^Csv'{
                $OutputFile += '.csv'
                $Result|Export-Csv $OutputFile -NoTypeInformation -ErrorAction Stop; 
                break
            }
            '^Text'{
                $OutputFile += '.txt'
                $Result|Out-File  -FilePath $OutputFile -Force; 
                break
            }
            '^ISE'{ $Result|out-gridview; break }
            default { $Result| out-default ;  break} 
        }
        if(-not($Result.get_Count())){ 
            [PSIrivenEvents]::DisplayMessage('No VM Snapshot found in the current vCenter.', 'yellow') 
            [PSIrivenUtils]::AddNewLine()
        }
        if($? -eq $true){
            [PSIrivenEvents]::DisplayMessage('Job Successfully finished ', 'green')
            [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
            [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
            sleep 1
            [PSIrivenEvents]::DisplayMessage("done!", "green")
            [PSIrivenUtils]::AddNewLine()
        }
     } #end Method




    GetStats()
    {
        $MenusItems = ( $this.Settings.DisplayMode.GetEnumerator()| ForEach-Object{$_.Name}| sort-object)
        [String]$OutputMode = $([PSIrivenMenu]::Generate($MenusItems, "PLEASE CHOOSE THE DESIRED OUTPUT DESTINATION"))
        if (-not($OutputMode))
        {
          [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
          [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
          sleep 1
          [PSIrivenEvents]::DisplayMessage("done!", "green")
          [PSIrivenUtils]::AddNewLine()
          Exit
        }
        $Result = New-Object System.Collections.ArrayList
        $Total = $this.VMObject.count
        $start = (Get-Date).AddDays(-30)
        $finish = Get-Date
        $counter = 0
        $this.VMObject | where {$_.PowerState -match "On"} |ForEach-Object{
            if([Object]::ReferenceEquals((Get-NetworkAdapter -VM $_.Name), $NULL)){continue; $Total--;}
            if(($_.Guest.Nics).Count -eq 0){continue;}
            $vCenter = $_.Uid.Substring($_.Uid.IndexOf('@')+1).Split(":")[0]
            if($this.Settings.ShowProgress)
            {
                $counter++
                $Parameters = @{ Activity = "vCEnter $($vCenter): -- Retrieving Virtual Machine Informations  -->";
                                 Status = "-- Querying VM: [{0} of {1}]" -f $($counter), $($Total);
                                 CurrentOperation = $_;
                                 PercentComplete = (($counter /  $Total) * 100) 
                               }     
                Write-Progress @Parameters
            }                

            $QuickStats = get-stat -Entity $_.Name -Stat "cpu.usage.average","mem.usage.average","net.usage.average","disk.usage.average" -IntervalMins 5 -Start $start -Finish $finish
            $VmStats = New-Object -Type PSObject -Property ([ordered]@{
                Name = $_.Name
                PowerState = $_.PowerState
                ESXHost = $_.VMHost 
                AvgMemoryUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "mem.usage.average"} | Measure-Object -Property Value -Average).Average) + ' %'
                MaxMemoryUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "mem.usage.average"} | Measure-Object -Property Value -Maximum).Maximum) + ' %'
                AvgCPUUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "cpu.usage.average"} | Measure-Object -Property Value -Average).Average) + ' %'
                MaxCPUUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "cpu.usage.average"} | Measure-Object -Property Value -Maximum).Maximum) + ' %'
                AvgNetworkUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "net.usage.average"} | Measure-Object -Property Value -Average).Average) + ' KBps'
                MaxNetworkUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "net.usage.average"} | Measure-Object -Property Value -Maximum).Maximum) + ' KBps'
                AvgDiskUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "disk.usage.average"} | Measure-Object -Property Value -Average).Average) + ' KBps'
                MaxDiskUsage = $("{0:N2}" -f ($QuickStats | Where-Object {$_.MetricId -eq "disk.usage.average"} | Measure-Object -Property Value -Maximum).Maximum) + ' KBps'

            })
            $Result.Add($VmStats) | Out-Null
            if(-not($this.Settings.ShowProgress)) {$VmStats}
            }
            if($this.Settings.ShowProgress) { Write-Progress -Activity "Completed" -Completed ;} 
            if(-not([PSIrivenUtils]::PathExists($this.Settings.OutputsDirectory)))
            {[PSIrivenUtils]::MakeDirectory($this.Settings.OutputsDirectory)}
            $OutputFile = (Join-Path $this.Settings.OutputsDirectory $((Get-Datacenter|select -ExpandProperty Name) + '_VirtualmachineStatistics'))
            switch -regex ($OutputMode)
            {
                '^Csv'{
                    $OutputFile += '.csv'
                    $Result|Export-Csv $OutputFile -NoTypeInformation -ErrorAction Stop; 
                    break
                }
                '^Text'{
                    $OutputFile += '.txt'
                    $Result|Out-File  -FilePath $OutputFile -Force; 
                    break
                }
                '^ISE'{ $Result|out-gridview; break }
                default { $Result| out-default ;  break} 
            }
            if($? -eq $true){
                [PSIrivenEvents]::DisplayMessage('Job Successfully finished ', 'green')
                [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
                [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
                sleep 1
                [PSIrivenEvents]::DisplayMessage("done!", "green")
                [PSIrivenUtils]::AddNewLine()
            }

           # return $Result
    } # END GetStats  

    GetNetworkReport()
    {
        if(-not([PSIrivenUtils]::PropertyExists($this.Settings,'MinAge'))){$this.Settings.Set_Item('MinAge','0')}
        $MenusItems = ( $this.Settings.DisplayMode.GetEnumerator()| ForEach-Object{$_.Name}| sort-object)
        [String]$OutputMode = $([PSIrivenMenu]::Generate($MenusItems, "PLEASE CHOOSE THE DESIRED OUTPUT DESTINATION"))
        if (-not($OutputMode))
        {
          [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
          [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
          sleep 1
          [PSIrivenEvents]::DisplayMessage("done!", "green")
          [PSIrivenUtils]::AddNewLine()
          Exit
        }
        $Result = New-Object System.Collections.ArrayList
        $Total = $this.VMObject.count
        $counter = 0
        $this.VMObject | Where-Object {($_.PowerState -match "On") -And ($_.ExtensionData.Guest.ToolsStatus -NotLike "*NotInstalled")} |ForEach-Object{
            if([Object]::ReferenceEquals((Get-NetworkAdapter -VM $_.Name), $NULL)){continue; $Total--;}
            if(($_.Guest.Nics).Count -eq 0){continue;}
            $vCenter = $_.Uid.Substring($_.Uid.IndexOf('@')+1).Split(":")[0]
            if($this.Settings.ShowProgress)
            {
                $counter++
                $Parameters = @{ Activity = "vCEnter $($vCenter): -- Retrieving Virtual Machine Informations  -->";
                                 Status = "-- Querying VM: [{0} of {1}]" -f $($counter), $($Total);
                                 CurrentOperation = $_;
                                 PercentComplete = (($counter /  $Total) * 100) 
                               }     
                Write-Progress @Parameters
            }                
            $VmIpStack = ($_.ExtensionData.Guest.IpStack)
            $VmRoutes = ($VmIpStack.IpRouteConfig.IpRoute)
            $Gateway = ($VmRoutes.Gateway.IpAddress | where {$_ -ne $null}| select -uniq)
            $NetworkAdapters = (Get-NetworkAdapter -Vm $_.Name)
            $NicType = ($NetworkAdapters| Select -ExpandProperty Type| select -uniq)
            if (-not($Gateway)) { $Gateway = '-' }
            if (-not($NicType)) { $NicType = '-' }
            $VmGuest = Get-VMGuest  -VM $_.Name
            $Network = New-Object -TypeName System.Collections.Generic.List[String]
            $VmRoutes|foreach-object{
                if (($VmGuest.IPAddress -replace "[0-9]$|[1-9][0-9]$|1[0-9][0-9]$|2[0-4][0-9]$|25[0-5]$", "0" | select -uniq) -contains $_.Network) {
                    $Network.Add($_.Network + '/' + $_.PrefixLength) | Out-Null
                }
            }

            $VmReport = New-Object -Type PSObject -Property ([ordered]@{
                Name = $_.Name
                PowerState = $_.PowerState 
                Folder = ($_.Folder).Name          
                IPAddress = [system.String]::Join(', ', $_.Guest.IPAddress)
                SubnetMask = [system.String]::Join(', ', "$Network")
                MacAddress = [system.String]::Join(', ', ($NetworkAdapters|Select -ExpandProperty MacAddress )) #($NetworkAdapters|Select -ExpandProperty MacAddress ) -join ' , '
                Gateway = [system.String]::Join(', ', $Gateway)
                TotalNics = ($_.Guest.Nics).Count                    
                DNS =  [system.String]::Join(', ', $VmIpStack.DnsConfig.IpAddress)
                NicType = [system.String]::Join(', ', $NicType)
                PortGroup = [system.String]::Join(', ', $NetworkAdapters.NetworkName)
                VMHost = ($_.VMHost).Name        
                VMHostId = $_.VMHostId
                Cluster = ($_.VMHost).Parent
                VCenter = $vCenter
            })
            $Result.Add($VmReport) | Out-Null
            if(-not($this.Settings.ShowProgress)) {$VmReport}
            }
            if($this.Settings.ShowProgress) { Write-Progress -Activity "Completed" -Completed ;} 
            if(-not([PSIrivenUtils]::PathExists($this.Settings.OutputsDirectory)))
            {[PSIrivenUtils]::MakeDirectory($this.Settings.OutputsDirectory)}
            $OutputFile = (Join-Path $this.Settings.OutputsDirectory $((Get-Datacenter| Select-Object -first 1 -ExpandProperty Name) + '_VirtualmachineNetworkInfos'))
            switch -regex ($OutputMode)
            {
                '^Csv'{
                    $OutputFile += '.csv'
                    $Result|Export-Csv $OutputFile -NoTypeInformation -ErrorAction Stop; 
                    break
                }
                '^Text'{
                    $OutputFile += '.txt'
                    $Result|Out-File  -FilePath $OutputFile -Force; 
                    break
                }
                '^ISE'{ $Result|out-gridview; break }
                default { $Result| out-default ;  break} 
            }
            if($? -eq $true){
                [PSIrivenEvents]::DisplayMessage('Job Successfully finished ', 'green')
                [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
                [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
                sleep 1
                [PSIrivenEvents]::DisplayMessage("done!", "green")
                [PSIrivenUtils]::AddNewLine()
            }

           # return $Result
    } # END GetNetworkReport      
     GetHotPlugOptionsInfos()
    {
        if(-not([PSIrivenUtils]::PropertyExists($this.Settings,'MinAge'))){$this.Settings.Set_Item('MinAge','0')}
        $MenusItems = ( $this.Settings.DisplayMode.GetEnumerator()| ForEach-Object{$_.Name}| sort-object)
        [String]$OutputMode = $([PSIrivenMenu]::Generate($MenusItems, "PLEASE CHOOSE THE DESIRED OUTPUT DESTINATION"))
        if (-not($OutputMode))
        {
          [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
          [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
          sleep 1
          [PSIrivenEvents]::DisplayMessage("done!", "green")
          [PSIrivenUtils]::AddNewLine()
          Exit
        }
        $Result = New-Object System.Collections.ArrayList
        $Total = $this.VMObject.count
        $counter = 0
        $this.VMObject | Where-Object {($_.PowerState -match "On") -And ($_.ExtensionData.Guest.ToolsStatus -NotLike "*NotInstalled")} |ForEach-Object{
            $vCenter = $_.Uid.Substring($_.Uid.IndexOf('@')+1).Split(":")[0]
            if($this.Settings.ShowProgress)
            {
                $counter++
                $Parameters = @{ Activity = "vCEnter $($vCenter): -- Retrieving Virtual Machine Informations  -->";
                                 Status = "-- Querying VM: [{0} of {1}]" -f $($counter), $($Total);
                                 CurrentOperation = $_;
                                 PercentComplete = (($counter /  $Total) * 100) 
                               }     
                Write-Progress @Parameters
            }                
            $VMView = (Get-VM -Name $_.Name | Get-View) 
            $VmReport = New-Object -Type PSObject -Property ([ordered]@{
                Name = $_.Name
                PowerState = $_.PowerState 
                CpuHotAddEnabled = ($VMView.Config).CpuHotAddEnabled        
                MemoryHotAddEnabled = ($VMView.Config).MemoryHotAddEnabled  
                VMHost = ($_.VMHost).Name        
                Cluster = ($_.VMHost).Parent
                VCenter = $vCenter
            })
            $Result.Add($VmReport) | Out-Null
            if(-not($this.Settings.ShowProgress)) {$VmReport}
            }
            if($this.Settings.ShowProgress) { Write-Progress -Activity "Completed" -Completed ;} 
            if(-not([PSIrivenUtils]::PathExists($this.Settings.OutputsDirectory)))
            {[PSIrivenUtils]::MakeDirectory($this.Settings.OutputsDirectory)}
            $OutputFile = (Join-Path $this.Settings.OutputsDirectory $((Get-Datacenter| Select-Object -first 1 -ExpandProperty Name) + '_VirtualmachineSpecs'))
            #$OutputFile = (Join-Path $this.Settings.OutputsDirectory 'MONTSOURIS_VirtualmachineSpecs')
            switch -regex ($OutputMode)
            {
                '^Csv'{
                    $OutputFile += '.csv'
                    $Result|Export-Csv $OutputFile -NoTypeInformation -ErrorAction Stop; 
                    break
                }
                '^Text'{
                    $OutputFile += '.txt'
                    $Result|Out-File  -FilePath $OutputFile -Force; 
                    break
                }
                '^ISE'{ $Result|out-gridview; break }
                default { $Result| out-default ;  break} 
            }
            if($? -eq $true){
                [PSIrivenEvents]::DisplayMessage('Job Successfully finished ', 'green')
                [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
                [PSIrivenEvents]::DisplayMessage(("." * 10), 'white', $true)
                sleep 1
                [PSIrivenEvents]::DisplayMessage("done!", "green")
                [PSIrivenUtils]::AddNewLine()
            }

           # return $Result
    } # END GetHotPlugOptionsInfos 

}