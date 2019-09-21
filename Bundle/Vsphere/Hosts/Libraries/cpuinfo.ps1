Function Get-HostCPUInfo {
	Param(
		[Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true)][String]$vmHost
	)
    
    $server = get-VMHost $vmHost

	$object = New-Object -TypeName PSObject
	$object | Add-Member -type NoteProperty -name HostName -value $server.Name
	$object| Add-Member -type NoteProperty -name Model -value $server.ExtensionData.summary.hardware.CPuModel
    $object| Add-Member -type NoteProperty -name CpuMhz -value $server.ExtensionData.summary.hardware.CpuMhz
    $object| Add-Member -type NoteProperty -name CpuSockets -value $server.ExtensionData.summary.hardware.NumCpuPkgs
    $object| Add-Member -type NoteProperty -name CpuCores -value $server.ExtensionData.summary.hardware.NumCpuCores
    $object| Add-Member -type NoteProperty -name CpuThreds -value $server.ExtensionData.summary.hardware.NumCpuThreads
    Return ($object)
}

# add the PowerClI VMware snapins
 Add-PSSnapin vmware*

# Connect to the vCenter server
$vCenter = Read-Host "Enter your vCenter server name"
Connect-VIServer $vCenter

# Get a list of vmware hosts
$vmHostList = Get-VMHost

$output = @()
foreach ($vmHost in $vmHostList) {
   $output += Get-HostCPUInfo -vmHost $vmHost.name #| select hostname, CpuSockets, CpuCores
}
$output | ft