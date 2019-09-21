function Get-IPAddressRange(){
  param (
    [Parameter(Mandatory=$true, Position=0)][string]$IPRange,
    [Parameter(Mandatory=$false, Position=1)]$PadStart,
    [Parameter(Mandatory=$false, Position=2)]$PadEnd
    ) 
  $PADRegex = '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
  $IPRegex = '^(?<network>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3})(?<machine>(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$'
  $IPRangeRegex = '^(?<prefix>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3})(?<min>(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(?<del>[-\/])(?<max>(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$'
  if($PadStart -Match $IPRegex){ $PadStart = $Matches.machine }
  if( -not($PadStart) -or ($PadStart -NotMatch $PADRegex)){ $PadStart = 1 }
  if($PadEnd -Match $IPRegex){ $PadEnd = $Matches.machine }
  if( -not($PadEnd) -or ($PadEnd -NotMatch $PADRegex)){ $PadEnd = 1 }
  if($IPRange  -Match $IPRangeRegex)
  {
    $Prefix = $Matches.prefix
    $Start = [Net.IPAddress]::Parse($Prefix + $Matches.min)
    $Delimiter = $Matches.del
    if( -not($Delimiter -Contains '/')){ 
      if([int]$Matches.min -gt [int]$Matches.max){ write-host "The first IP address can not be greater than the last one."; exit}
      $End = [Net.IPAddress]::Parse($Prefix + $Matches.max)
      $FirstAddress = ip2long -ip $Start.ipaddresstostring 
      $LastAddress = ip2long -ip $End.ipaddresstostring
    }
    else {
      if(([int]$Matches.max -lt 1) -Or ([int]$Matches.max -gt 32)){ write-host "invalid subnet"; exit}

      $maskaddr = [Net.IPAddress]::Parse((long2ip -int ([convert]::ToInt64(("1"*$Matches.max+"0"*(32-$Matches.max)),2))))
      $networkaddr = new-object net.ipaddress ($maskaddr.address -band $Start.address)
      $broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address)) 
      $FirstAddress = (ip2long -ip $networkaddr.ipaddresstostring) + 1 + $PadStart 
      $LastAddress = (ip2long -ip $broadcastaddr.ipaddresstostring) - 1 - $PadEnd
    }
  }
  else
  { write-host "invalid IP range"; exit}
  $IpList = New-Object System.Collections.ArrayList
  for ($ip = $FirstAddress; $ip -le $LastAddress; $ip++) 
  { 
    $IpList.Add((long2ip -int $ip)) > $null
  }
  return $IpList;
}


function ip2long ()
{ 
  param ($ip) 
  $octets = $ip.split(".") 
  return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3]) 
} 
 
function long2ip() { 
  param ([int64]$int) 

  return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
} 
cls

$test = (Get-IPAddressRange "200.168.1.30/24" "80" "100")
#$IPs = (Get-IPAddressRange -IPRange "200.168.1.30/24" | Where-Object { ((ip2long -ip "$_") -ge $minip) -and  ((ip2long -ip "$_") -le $maxip)})
#$IPs
$test
#$IPRegex = '((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
$IPRegex = '^(?<network>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3})(?<machine>(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$'
$PADRegex = '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
$PadEnd = "200.168.1.80"
if($PadEnd -Match $IPRegex){ $PadEnd = $Matches.machine }
if( -not($PadEnd) -or ($PadEnd -NotMatch $PADRegex)){ $PadEnd = 1 }
$PadEnd



if([int]$PadEnd -ne 1){ $PadEnd = [int]$PadEnd + [int]$PadStart}