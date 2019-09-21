#https://www.virtualease.fr/powercli-script-contention-overcommit
#param($vmhosts="*")
$Cluster_Name="CLOAUBSIDWIS04"
#$vmhosts=Get-Cluster $Cluster_Name|Get-VMHost
#$vms=Get-Cluster $Cluster_Name|Get-VM|where {$_.PowerState -eq "PoweredOn"}
$cvalue = New-Object psobject

$Output=@()
$Output1=@()
$totalhostram=0;
$totalvram=0;
$totalratio=0;

Get-Cluster $Cluster_Name|Get-VMHost|Foreach-Object{
    $ratio=$null;
    $hostvram=0;
    Get-Cluster $Cluster_Name|Get-VMHost $_.Name|Get-VM| where {$_.PowerState -eq "PoweredOn"}|Foreach-Object{
        $vram=0;
        $vram = $_.MemoryGB;
        $hostvram += $vram
    }
    $totalvram += $hostvram;
    $hostram="{0:N0}" -f ($_.memorytotalGB);
    $ratio = "{0:N1}" -f ($hostvram/$hostram);

    $hvalue= New-Object psobject;
    $hvalue| Add-Member -MemberType Noteproperty "Hostname" -value $_.name;
    $hvalue| Add-Member -MemberType Noteproperty "hRAM" -Value $hostram;
    $hvalue| Add-Member -MemberType Noteproperty "vRAM" -Value $hostvram;
    $hvalue| Add-Member -MemberType Noteproperty "Ratio" -Value $ratio;$Output+=$hvalue;
    $totalhostram += $hostram  

}
    $totalratio = "{0:N1}" -f ($totalvram/$totalhostram);
    $cvalue= New-Object psobject;
    $cvalue| Add-Member -MemberType Noteproperty "Cluster" -value "$Cluster_Name";
    $cvalue| Add-Member -MemberType Noteproperty "hRAM" -Value $totalhostram;
    $cvalue| Add-Member -MemberType Noteproperty "vRam" -Value $totalvram;
    $cvalue| Add-Member -MemberType Noteproperty "Ratio" -Value $totalratio;
    $Output1+=$cvalue;
    $Output|ft -autosize;
    $Output1|ft -autosize
