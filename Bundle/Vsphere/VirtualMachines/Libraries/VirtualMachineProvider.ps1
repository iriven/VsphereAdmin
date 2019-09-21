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
class PSIrivenVMDeploy{

    [ValidateNotNullOrEmpty()]
    [HashTable]
    hidden $Settings;


    PSIrivenVMDeploy([HashTable]$Config)
    {
        try {
            if (-not([PSIrivenUtils]::PropertyExists($Config,'DisplayMode')) -or ($Config.DisplayMode.get_Count() -eq 0)) 
            {
                throw "Error: Can't initialize PSIrivenVMDeploy Class; Invalid Configuration Data Given."
            }
            if(-not([PSIrivenUtils]::PropertyExists($Config,'OutputsDirectory')))
            {$Config.Set_Item('OutputsDirectory',(Split-Path $MyInvocation.MyCommand.Path -Parent))}
            if(-not([PSIrivenUtils]::PropertyExists($Config,'ShowProgress'))){$Config.Set_Item('ShowProgress','True')}
            
            $Config.Set_Item('ShowProgress',[PSIrivenUtils]::GetBoolean($Config.ShowProgress))
            $this.Settings += $Config
        }
        catch [Exception]{
                write-error -Message $_.Exception.Message  -EA Stop
        }
    }



    [System.String]GetNamingConvention([String]$VMNamePrefix, [Int]$VmCount)
    {
        $OutPut = $VMNamePrefix
        $Suffix = $((Get-Datacenter).Substring(0,1)).ToLower()
        switch ($VmCount) {
           {$VmCount -ge 100} {$OutPut += '{0:D3}'; break}
           default {$OutPut += '{0:D2}'; break}
        }
        $OutPut += '-' + $Suffix
        return $OutPut
    }


}


#  #Procedure
#  #https://pubs.vmware.com/vsphere-5-5/index.jsp?topic=%2Fcom.vmware.powercli.ug.doc%2FGUID-8A6032B3-41E0-474E-9C18-664B4BABAC3A.html
#  #Define the naming convention for the virtual machines.
#  $vmNameTemplate = "VM-{0:D3}"
#  #Save the cluster in which the virtual machines should be created into a variable.
#  $cluster = Get-Cluster MyCluster
#  #Save the template on which the virtual machines should be based into a variable.
#  $template = Get-Template MyTemplate
#  #Create the virtual machines.
#  $vmList = @()
#  #    
#  for ($i = 1; $i –le 100; $i++) {
#      $vmName = $vmNameTemplate –f $i
#      $vmList += New-VM –Name $vmName –ResourcePool $cluster –Template $template
#  }
#  #Save the static IP addresses from the stored CSV file into a variable.
#  $staticIpList = Import-CSV C:\StaticIPs.csv
#  #Create the customization specification.
#  $linuxSpec = New-OSCustomizationSpec –Name LinuxCustomization –Domain vmware.com –DnsServer "192.168.0.10", "192.168.0.20" –NamingScheme VM –OSType Linux –Type NonPersistent
#  #Apply the customization specification to each virtual machine.
#  for ($i = 0; $i –lt $vmList.Count; $i++) {
#      $VMHost = Get-Cluster $ClusterName |Get-VMHost | Get-Random
#      # Acquire a new static IP from the list
#      $ip = $staticIpList[$i].IP
#      # Remove any NIC mappings from the specification
#      $nicMapping = Get-OSCustomizationNicMapping –OSCustomizationSpec $linuxSpec
#      Remove-OSCustomizationNicMapping –OSCustomizationNicMapping $nicMapping –Confirm:$false
#      # Retrieve the virtual machine’s network adapter attached to the public network named "Public"
#      $publicNIC = $vmList[$i] | Get-NetworkAdapter | where {$_.NetworkName -eq "Public"}
#      # Retrieve the virtual machine’s network adapter attached to the private network named "Private"
#      $privateNIC = $vmList[$i] | Get-NetworkAdapter | where {$_.NetworkName -eq "Private"}
#      # Create a NIC mapping for the "Public" NIC that should use static IP
#      $linuxSpec | New-OSCustomizationNicMapping –IpMode UseStaticIP –IpAddress $ip –SubnetMask "255.255.252.0" –DefaultGateway "192.168.0.1" –NetworkAdapterMac $publicNIC.MacAddress
#      # Create a NIC mapping for the "Private" NIC that should use DHCP
#      $linuxSpec | New-OSCustomizationNicMapping –IpMode UseDhcp –NetworkAdapterMac $privateNIC.MacAddress
#      # Apply the customization
#      Set-VM –VM $vmList[$i] –OSCustomizationSpec $linuxSpec –Confirm:$false
#  }#