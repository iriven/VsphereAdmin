Get-Cluster | Select Name, @{N="Host Count"; E={($_ | Get-VMHost).Count}},  @{N="VM Count"; E={($_ | Get-VM).Count}}
get-datacenter "VDR" | Get-Cluster | Select Name, @{N="Host Count"; E={($_ | Get-VMHost).Count}},  @{N="VM Count"; E={($_ | Get-VM).Count}},  @{N="Datastore Count"; E={($_ | Get-Datastore).Count}}|ft -autosize

Get-VMHost | Select @{N=“Cluster“;E={Get-Cluster -VMHost $_}}, Name, @{N=“NumVM“;E={($_ | Get-VM).Count}} | Sort Cluster, Name | Export-Csv -NoTypeInformation c:\clu-host-numvm.csv



#Resource Pools with Ballooning and Swapping

$myCol = @()
foreach($clus in (Get-Cluster)){
 foreach($rp in (Get-ResourcePool -Location $clus | Get-View | Where-Object `
  {$_.Name -ne "Resources" -and `
   $_.Summary.QuickStats.BalloonedMemory -ne "0"})){
   $Details = "" | Select-Object Cluster, ResourcePool, `
   SwappedMemory ,BalloonedMemory
 
    $Details.Cluster = $clus.Name
    $Details.ResourcePool = $rp.Name
    $Details.SwappedMemory = $rp.Summary.QuickStats.SwappedMemory
    $Details.BalloonedMemory = $rp.Summary.QuickStats.BalloonedMemory
 
    $myCol += $Details
  }
}
$myCol

#VMs with Ballooning and Swapping

$myCol = @()
foreach($vm in (Get-View -ViewType VirtualMachine | Where-Object `
  {$_.Summary.QuickStats.BalloonedMemory -ne "0"})){
   $Details = "" | Select-Object VM, `
   SwappedMemory ,BalloonedMemory
 
    $Details.VM = $vm.Name
    $Details.SwappedMemory = $vm.Summary.QuickStats.SwappedMemory
    $Details.BalloonedMemory = $vm.Summary.QuickStats.BalloonedMemory
 
    $myCol += $Details
  }
$myCol


# VMs Network Info
(get-vm) | %{
  $vm = $_
  echo $vm.name----
  $vm.Guest.Nics | %{
    $vminfo = $_
    echo $vminfo.NetworkName $vminfo.IPAddress $vminfo.MacAddress
    echo ";`n";
  }
}

#VMs Boot Time
$LastBootProp = @{
  Name = 'LastBootTime'
    Expression = {
      ( Get-Date ) - ( New-TimeSpan -Seconds $_.Summary.QuickStats.UptimeSeconds )
    }
}
 
Get-View -ViewType VirtualMachine -Property Name, Summary.QuickStats.UptimeSeconds | Select Name, $LastBootProp
#https://www.getshifting.com/wiki/powerclinotes


##Count Number of Paths Fibre Channel
$esxName​​ =​​ 'uk3p-esxi01*','uk3p-esx02*','uk3p-esx03*'
$report=​​ @()
$esxilist​​ =​​ Get-VMHost​​ -Name​​ $esxName

foreach(​​ $esxvm​​ in​​ $esxilist){

$esx​​ =​​ Get-VMHost​​ -Name​​ $esxvm
$esxcli​​ =​​ Get-EsxCli​​ -VMHost​​ $esxvm
$hba​​ =​​ Get-VMHostHba​​ -VMHost​​ $esx​​ -TypeFibreChannel​​ |​​ Select​​ -ExpandProperty​​ Name
$esxcli.storage.core.path.list()​​ |
Where{$hba​​ -contains​​ $_.Adapter}​​ |
Group-Object​​ -Property​​ Device​​ |​​ %{
 ​​ ​​ ​​ ​​​​ $row​​ =​​ ""​​ |​​ Select​​ ESXihost,​​ Lun,​​ NrPaths
 ​​ ​​ ​​ ​​​​ $row.ESXihost​​ =​​ $esxvm.name
 ​​ ​​ ​​ ​​​​ $row.Lun​​ =​​ $_.Name
 ​​ ​​ ​​ ​​​​ $row.NrPaths​​ =​​ $_.Group.Count
 ​​ ​​ ​​ ​​​​ $report​​ +=​​ $row
 ​​​​ }
}
$report​​ |​​ Export-Csv​​ esx-lun-path.csv​​ -NoTypeInformation​​ -UseCulture

#This function I wrote will return an object which contains the unique name of each OS for guests on a vCenter server. It will also show you the total number of VMs with that OS
#This function takes the parameter $vCenter. This should be the name of a vCenter server in your environment. You can also call the function as part of a foreach loop if you have multiple vCenter servers,
# running it once for each server and then returning that into another variable.

function Get-VMOSList {
    [cmdletbinding()]
    param($vCenter)
    Connect-VIServer $vCenter  | Out-Null
    [array]$osNameObject       = $null
    $vmHosts                   = Get-VMHost
    $i = 0
    foreach ($h in $vmHosts) {
        Write-Progress -Activity "Going through each host in $vCenter..." -Status "Current Host: $h" -PercentComplete ($i/$vmHosts.Count*100)
        $osName = ($h | Get-VM | Get-View).Summary.Config.GuestFullName
        [array]$guestOSList += $osName
        Write-Verbose "Found OS: $osName"
        
        $i++        
    }
    $names = $guestOSList | Select-Object -Unique
    $i = 0
    foreach ($n in $names) { 
    
        Write-Progress -Activity "Going through VM OS Types in $vCenter..." -Status "Current Name: $n" -PercentComplete ($i/$names.Count*100)
        $vmTotal = ($guestOSList | ?{$_ -eq $n}).Count
        
        $osNameProperty  = @{'Name'=$n} 
        $osNameProperty += @{'Total VMs'=$vmTotal}
        $osNameProperty += @{'vCenter'=$vcenter}
        $osnO             = New-Object PSObject -Property $osNameProperty
        $osNameObject     += $osnO
        $i++
    }    
    Disconnect-VIserver -force -confirm:$false  
    Return $osNameObject
}