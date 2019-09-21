Get-CLuster -PipelineVariable cluster |



-Process {

 

$reportCpu = @()

 

$reportMem = @()

 

Get-VMHost -Location $cluster -PipelineVariable esx |



ForEach-Object -Process {

 

$vCPU = Get-VM -Location $esx | where { $_.PowerState -match "on" } | Measure-Object -Property NumCpu -Sum | select -ExpandProperty Sum



$reportCpu += $esx | Select Name, @{N = 'pCPU cores available'; E = { $_.NumCpu } },



= 'vCPU assigned to VMs'; E = { $vCPU } },



= 'Ratio'; E = { [math]::Round($vCPU / $_.NumCpu, 1) } },



= 'CPU Overcommit (%)'; E = { [Math]::Round(100 * (($vCPU - $_.NumCpu) / $_.NumCpu), 1) } }

 

$vMem = get-vm -location $esx | where { $_.PowerState -match "on" } | measure-object -property MemoryGB -SUM | Select -Expandproperty Sum



$reportMem += $esx | Select Name, @{N = 'Total Memory Available'; E = { [Math]::Round($_.MemoryTotalGB), 1 } },



= 'Memory Assigned to VMs'; E = { $vMem } },



= 'Ratio'; E = { [math]::Round(100 * ($vMem / $_.MemoryTotalGB), 1) } },



= 'Memory Overcommit (%)'; E = { [Math]::Round(100 * (($vMem - $_.MemoryTotalGB) / $_.MemoryTotalGB), 1) } }   }

 

$reportCpu | Export-Excel -Path C:\OC\CPU_Overcommitment.xlsx -WorksheetName "CPU-$($cluster.Name)"



$reportMem | Export-Excel -Path C:\OC\CPU_Overcommitment.xlsx -WorksheetName "Memory-$($cluster.Name)"]}

 