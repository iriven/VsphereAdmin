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
class PSIrivenVMTools{


    [ValidateNotNullOrEmpty()][HashTable]
    hidden $Settings;
    
    [ValidateNotNullOrEmpty()]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]
    hidden $VMObject;

    PSIrivenVMTools([VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$VMs,[HashTable]$Config)
    {
        try {
            if (-not([PSIrivenUtils]::PropertyExists($Config,'DisplayMode')) -or ($Config.DisplayMode.get_Count() -eq 0)) 
            {
                throw "Error: Can't initialize PSIrivenVMTools Class; Invalid Configuration Data Given."
            }
            if(-not([PSIrivenUtils]::PropertyExists($Config,'OutputsDirectory')))
            {$Config.Set_Item('OutputsDirectory',(Split-Path $MyInvocation.MyCommand.Path -Parent))}
            if(-not([PSIrivenUtils]::PropertyExists($Config,'ShowProgress'))){$Config.Set_Item('ShowProgress','True')}
            
            $Config.Set_Item('ShowProgress',[PSIrivenUtils]::GetBoolean($Config.ShowProgress))
            $this.Settings += $Config
             $this.VMObject = $VMs | ? {$_.pstypenames -contains "VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl"}
            if (-not $this.VMObject){
                Throw "No Virtual Machine found.`nIs ""$VMs"" a VM Object?"
            }
        }
        catch [Exception]{
            write-error -Message $_.Exception.Message  -EA Stop
        }
    }

     CheckOutOfDateTools(){
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
        $this.VMObject |where {$_.ExtensionData.Guest.ToolsStatus -ne "toolsOk"}|ForEach-Object{
            if([Object]::ReferenceEquals((Get-NetworkAdapter -VM $_.Name), $NULL)){continue; $Total--;}
            if(($_.Guest.Nics).Count -eq 0){continue;}
            $vCenter = $_.Uid.Substring($_.Uid.IndexOf('@')+1).Split(":")[0]
            if($this.Settings.ShowProgress)
            {
                $counter++
                $Parameters = @{ Activity = "vCEnter $($vCenter): -- Retrieving Out of Date VM Tools  -->";
                                 Status = "-- Querying VM: [{0} of {1}]" -f $($counter), $($Total);
                                 CurrentOperation = $_;
                                 PercentComplete = (($counter /  $Total) * 100) 
                               }     
                Write-Progress @Parameters
            }
            $VmToolsReport = New-Object -Type PSObject -Property ([ordered]@{
                VirtualMachine = $_.Name
                PowerState = $_.PowerState
                ToolsStatus = $_.Guest.ExtensionData.ToolsStatus
                ToolsVersion = $_.ExtensionData.Guest.Toolsversion  
            })
            $Result.Add($VmToolsReport) | Out-Null
            if(-not($this.Settings.ShowProgress)) {$VmToolsReport}
        } #$this.VMObject
        if($this.Settings.ShowProgress) { Write-Progress -Activity "Completed" -Completed $true;} 
        if(-not([PSIrivenUtils]::PathExists($this.Settings.OutputsDirectory)))
        {[PSIrivenUtils]::MakeDirectory($this.Settings.OutputsDirectory)}
        $OutputFile = (Join-Path $this.Settings.OutputsDirectory $((Get-Datacenter|select -ExpandProperty Name) + '_ObsoleteVMTools'))
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
            [PSIrivenEvents]::DisplayMessage('No VM found in the current vCenter.', 'white') 
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
    } #CheckOutOfDateTools End



     GetToolsInfo(){
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
            $VmToolsReport = New-Object -Type PSObject -Property ([ordered]@{
                VirtualMachine = $_.Name
                HostName = $_.Guest.HostName
                PowerState = $_.PowerState
                ToolsStatus = $_.Guest.ExtensionData.ToolsStatus
                GuestToolsStatus = $($_.Guest.ExtensionData.ToolsRunningStatus).replace('guestTools','')
                ToolsVersion = $_.Guest.ToolsVersion
                ToolsVersionStatus = $($_.Guest.ExtensionData.ToolsVersionStatus).replace('guestTools','')
                ToolsInstallType = $_.Guest.ExtensionData.ToolsInstallType
                GuestFamily = $_.Guest.GuestFamily
                
                
            })
            $Result.Add($VmToolsReport) | Out-Null
            if(-not($this.Settings.ShowProgress)) {$VmToolsReport}
        } #$this.VMObject
        if($this.Settings.ShowProgress) { Write-Progress -Activity "Completed" -Completed ;} 
        if(-not([PSIrivenUtils]::PathExists($this.Settings.OutputsDirectory)))
        {[PSIrivenUtils]::MakeDirectory($this.Settings.OutputsDirectory)}
        $OutputFile = (Join-Path $this.Settings.OutputsDirectory $((Get-Datacenter|select -ExpandProperty Name) + '_VMToolsInfos'))
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
            [PSIrivenEvents]::DisplayMessage('No VM found in the current vCenter.', 'white') 
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
     } # end GetToolsInfo()
     

    


} # CLASS END