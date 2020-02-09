class PSIrivenVMSecurity{


    [ValidateNotNullOrEmpty()][HashTable]
    hidden $Settings;
    
    [ValidateNotNullOrEmpty()]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]
    hidden $VMObject;

    PSIrivenVMSecurity([VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$VMs,[HashTable]$Config)
    {
        try {
            if (-not([PSIrivenUtils]::PropertyExists($Config,'DisplayMode')) -or ($Config.DisplayMode.get_Count() -eq 0)) 
            {
                throw "Error: Can't initialize PSIrivenVMSecurity Class; Invalid Configuration Data Given."
            }
            if (-not([PSIrivenUtils]::PropertyExists($Config,'ExtraOptions')) -or ($Config.ExtraOptions.get_Count() -eq 0)) 
            {
                throw "Error: Can't initialize PSIrivenVMSecurity Class; Invalid Configuration ExtraOptions Data Given."
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


    ApplyHardening(){


        $VMConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    
        Foreach ($Option in $this.Settings.ExtraOptions.GetEnumerator()) {
        $OptionValue = New-Object VMware.Vim.optionvalue
        $OptionValue.Key = $Option.Key
        $OptionValue.Value = $Option.Value
        $VMConfigSpec.extraconfig += $OptionValue
        }
        ForEach ($VM in $this.VMObject){
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

    }







} # Class END