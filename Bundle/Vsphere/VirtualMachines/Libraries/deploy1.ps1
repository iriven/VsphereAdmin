#############################################################
# David Mitchell 2014/06/04
# Script to deploy VM(s) from Template(s) and set appropriate
# IP config for Windows VMs. Also sets # of CPUs, MemoryMB,
# port group.
# Moves deployed VM to specific VMs/Template blue folder.
# Assumptions:
# connected to viserver before running
# Customization spec and templates in place and tested
#https://blog.vmpros.nl/2011/01/16/vmware-deploy-multiple-vms-from-template-with-powercli/
#http://notesofascripter.com/2016/03/28/using-powercli-build-multiple-vms/
#https://www.jasemccarty.com/blog/powercli-commands-getset-oscustomizationnicmapping/
#https://www.youtube.com/watch?v=oKZdhPyXnFs
#############################################################

# Syntax and sample for CSV File:
# template,datastore,diskformat,vmhost,custspec,vmname,ipaddress,subnet,gateway,pdns,sdns,pwins,swins,datacenter,folder,stdpg,memsize,cpucount
# template.2008ent64R2sp1,DS1,thick,host1.domain.com,2008r2CustSpec,Guest1,10.50.35.10,255.255.255.0,10.50.35.1,10.10.0.50,10.10.0.51,10.10.0.50,10.10.0.51,DCName,FldrNm,stdpg.10.APP1,2048,1

#
$vmlist = Import-CSV “E:\DeployVMServers.csv”

# Load PowerCLI
$psSnapInName = “VMware.VimAutomation.Core”
if (-not (Get-PSSnapin -Name $psSnapInName -ErrorAction SilentlyContinue))
{
# Exit if the PowerCLI snapin can’t be loaded
Add-PSSnapin -Name $psSnapInName -ErrorAction Stop
}

connect-viserver ESX.yourdomain.local

foreach ($item in $vmlist) {

# Map variables
$template = $item.template
$datastore = $item.datastore
$diskformat = $item.diskformat
$vmhost = $item.vmhost
$custspec = $item.custspec
$vmname = $item.vmname
$ipaddr = $item.ipaddress
$subnet = $item.subnet
$gateway = $item.gateway
$pdns = $item.pdns
$sdns = $item.sdns
$datacenter = $item.datacenter
$destfolder = $item.folder
$stdpg = $item.stdpg
$memsize = $item.memsize
$cpucount = $item.cpucount

#Configure the Customization Spec info
Get-OSCustomizationSpec $custspec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -IpAddress $ipaddr -SubnetMask $subnet -DefaultGateway $gateway -Dns $pdns,$sdns

#Deploy the VM based on the template with the adjusted Customization Specification
New-VM -Name $vmname -Template $template -Datastore $datastore -DiskStorageFormat $diskformat -VMHost $vmhost | Set-VM -OSCustomizationSpec $custspec -Confirm:$false

#Move VM to Application Group’s folder
Get-vm -Name $vmname | move-vm -Destination $(Get-Folder -Name $DestFolder -Location $(Get-Datacenter $Datacenter))

#Set the Port Group Network Name (Match PortGroup names with the VLAN name)
Get-VM -Name $vmname | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $stdpg -Confirm:$false

#Set the number of CPUs and MB of RAM
Get-VM -Name $vmname | Set-VM -MemoryMB $memsize -NumCpu $cpucount -Confirm:$false

}

Disconnect-VIServer ESX.yourdomain.local

#######################################################################################################################################
# https://communities.vmware.com/thread/440233
#######################################################################################################################################
Here is how I get a datastore with enough space. I probably can’t help debug this if you run in to errors but thought I’d share:

(edited the post to add where I the vmhost)
#Get an ESX host at random to find datastores
$VMHost = Get-Cluster $ClusterName |Get-VMHost | Get-Random

# Create new properties for Datastore calculations
New-VIProperty -Name UsedGB -ObjectType Datastore `-Value {
    param($ds)
    [Math]::Round(($ds.ExtensionData.Summary.Capacity – $ds.ExtensionData.Summary.FreeSpace)/1GB,1)
} `-BasedONextensionProperty 'Summary' `-Force

New-VIProperty -Name ProvisionedGB -ObjectType Datastore `-Value {param($ds)
[Math]::Round(($ds.ExtensionData.Summary.Capacity – $ds.ExtensionData.Summary.FreeSpace + $ds.ExtensionData.Summary.Uncommitted)/1GB,1)} `-BasedONextensionProperty ‘Summary’ `-Force

# Get datastore like a particular name (win*)and where used and provisioned are within our acceptable range
# Selects the first one it finds

$Datastore = Get-Datastore -VMHost $VMHost | where {$_.Name -like “*win*”} |where-object {($_.UsedGB) -le 710 -and $_.ProvisionedGB -le 1360}|Select-Object -first 1

function getDatastoreWithEnoughSpace{
    param (
        [Parameter(Mandatory = $true,                            
        ValueFromPipeline = $True,                            
        Position = 0)]
        [system.string]$ClusterName,                 
    [Parameter(Mandatory = $false,                           
        ValueFromPipeline = $true,                            
        Position = 1)]
    [system.string]$DatastorePattern   
    )
    $VMHost = Get-Cluster $ClusterName |Get-VMHost | Get-Random
    if (-not($DatastorePattern)) 
    {
        $Datastore = Get-Datastore -VMHost $VMHost | where {$_.Name -NotLike "*Local*" -And $_.FreespaceGB -gt 50} `
                    | Sort-Object -Property FreespaceGB -Descending:$true | Select-Object -First 1 
    }
    else 
    {
        $Datastore = Get-Datastore -VMHost $VMHost | where {$_.Name -Match "$DatastorePattern" -And $_.Name -NotLike "*Local*" -And $_.FreespaceGB -gt 50} `
                    | Sort-Object -Property FreespaceGB -Descending:$true | Select-Object -First 1 
    }
    $Datastore
}




## if the freespace plus a bit of buffer space is greater than the size needed for the new VM
if (($oDatastoreWithMostFree.FreespaceGB + 20) -gt $intNewVMDiskSize) {<# do the provisioning to this datastore #>}
else {"oh, no -- not enough freespace on datastore '$($oDatastoreWithMostFree.Name)' to provision new VM"}





############################################################################################################################################################################################################################################################################################
#https://vdc-repo.vmware.com/vmwb-repository/dcr-public/a5963bb3-674c-4fb1-92aa-df896e3b4758/ad921b7b-3e4f-4404-b98b-b6c4aa53f152/doc/GUID-8A6032B3-41E0-474E-9C18-664B4BABAC3A.html
############################################################################################################################################################################################################################################################################################

Create Multiple Virtual Machines with Two Network Adapters
You can deploy multiple virtual machines with two network adapters each and configure each adapter to use specific network settings by applying a customization specification.

You can configure each virtual machine to have one network adapter attached to a public network and one network adapter attached to a private network. You can configure the network adapters on the public network to use static IP addresses and the network adapters on the private network to use DHCP.

Prerequisites
Verify that you have defined a list of static IP addresses in a CSV file.

Procedure
1
Define the naming convention for the virtual machines.

$vmNameTemplate = "VM-{0:D3}"
2
Save the cluster in which the virtual machines should be created into a variable.

$cluster = Get-Cluster MyCluster
3
Save the template on which the virtual machines should be based into a variable.

$template = Get-Template MyTemplate
4
Create the virtual machines.

$vmList = @()
	
for ($i = 1; $i –le 100; $i++) {
    $vmName = $vmNameTemplate –f $i
    $vmList += New-VM –Name $vmName –ResourcePool $cluster –Template $template
}
5
Save the static IP addresses from the stored CSV file into a variable.

$staticIpList = Import-CSV C:\StaticIPs.csv
6
Create the customization specification.

$linuxSpec = New-OSCustomizationSpec –Name LinuxCustomization –Domain vmware.com –DnsServer "192.168.0.10", "192.168.0.20" –NamingScheme VM –OSType Linux –Type NonPersistent
7
Apply the customization specification to each virtual machine.

for ($i = 0; $i –lt $vmList.Count; $i++) {
    # Acquire a new static IP from the list
    $ip = $staticIpList[$i].IP

    # Remove any NIC mappings from the specification
    $nicMapping = Get-OSCustomizationNicMapping –OSCustomizationSpec $linuxSpec
    Remove-OSCustomizationNicMapping –OSCustomizationNicMapping $nicMapping –Confirm:$false

    # Retrieve the virtual machine’s network adapter attached to the public network named "Public"
    $publicNIC = $vmList[$i] | Get-NetworkAdapter | where {$_.NetworkName -eq "Public"}

    # Retrieve the virtual machine’s network adapter attached to the private network named "Private"
    $privateNIC = $vmList[$i] | Get-NetworkAdapter | where {$_.NetworkName -eq "Private"}

    # Create a NIC mapping for the "Public" NIC that should use static IP
    $linuxSpec | New-OSCustomizationNicMapping –IpMode UseStaticIP –IpAddress $ip –SubnetMask "255.255.252.0" –DefaultGateway "192.168.0.1" –NetworkAdapterMac $publicNIC.MacAddress

    # Create a NIC mapping for the "Private" NIC that should use DHCP
    $linuxSpec | New-OSCustomizationNicMapping –IpMode UseDhcp –NetworkAdapterMac $privateNIC.MacAddress

    # Apply the customization
    Set-VM –VM $vmList[$i] –OSCustomizationSpec $linuxSpec –Confirm:$false
}