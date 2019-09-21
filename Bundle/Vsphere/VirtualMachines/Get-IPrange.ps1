#function Get-IPrange
#{
#<# 
#  .SYNOPSIS  
#    Get the IP addresses in a range 
#  .EXAMPLE 
#   Get-IPrange -start 192.168.8.2 -end 192.168.8.20 
#  .EXAMPLE 
#   Get-IPrange -ip 192.168.8.2 -mask 255.255.255.0 
#  .EXAMPLE 
#   Get-IPrange -ip 192.168.8.3 -cidr 24 
##> 
# 
#param 
#( 
#  [string]$start, 
#  [string]$end, 
#  [string]$ip, 
#  [string]$mask, 
#  [int]$cidr 
#) 
# 
#function ip2long () { 
#  param ($ip) 
# 
#  $octets = $ip.split(".") 
#  return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3]) 
#} 
# 
#function long2ip() { 
#  param ([int64]$int) 
#
#  return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
#} 
# 
#if ($ip) {$ipaddr = [Net.IPAddress]::Parse($ip)} 
#if ($cidr) {$maskaddr = [Net.IPAddress]::Parse((long2ip -int ([convert]::ToInt64(("1"*$cidr+"0"*(32-$cidr)),2)))) } 
#if ($mask) {$maskaddr = [Net.IPAddress]::Parse($mask)} 
#if ($ip) {$networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address)} 
#if ($ip) {$broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address))} 
# 
#if ($ip) { 
#  $FirstAddress = ip2long -ip $networkaddr.ipaddresstostring 
#  $LastAddress = ip2long -ip $broadcastaddr.ipaddresstostring 
#} else { 
#  $FirstAddress = ip2long -ip $start 
#  $LastAddress = ip2long -ip $end 
#} 
# 
# 
#for ($i = $FirstAddress; $i -le $LastAddress; $i++) 
#{ 
#  long2ip -int $i 
#}
#
#}

function Get-IPListFromRange(){
  param ($IPRange) 
  $IPRangeRegex = '^(?<prefix>(\d{1,3}\.){3})\.(?<min>\d{1,3})(?<del>[-\/])(?<max>\d{1,3})$'

  if($IPRange  -Match $IPRangeRegex)
  {
    $Prefix = $Matches.prefix
    $Start = [Net.IPAddress]::Parse($Prefix + '.' + $Matches.min)
    $Delimiter = $Matches.del

    if($Delimiter !== '/'){ 
      $End = [Net.IPAddress]::Parse($Prefix + '.' + $Matches.max)
      $FirstAddress = ip2long -ip $Start.ipaddresstostring 
      $LastAddress = ip2long -ip $End.ipaddresstostring
    }
    else {
      $ipaddr = $Start
      $cidr = $Matches.max
      $maskaddr = [Net.IPAddress]::Parse((long2ip -int ([convert]::ToInt64(("1"*$cidr+"0"*(32-$cidr)),2))))
      $networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address)
      $broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address)) 
      $FirstAddress = ip2long -ip $networkaddr.ipaddresstostring 
      $LastAddress = ip2long -ip $broadcastaddr.ipaddresstostring 
    }

  }
  else
  { write-host "invalid IP range"; exit}
  for ($ip = $FirstAddress; $ip -le $LastAddress; $ip++) 
  { 
    long2ip -int $ip 
  }

}



 


$IPregex='(?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))'
    If ($String -Match $IPregex) {$Matches.Address}


    ?<Address>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3})


    \