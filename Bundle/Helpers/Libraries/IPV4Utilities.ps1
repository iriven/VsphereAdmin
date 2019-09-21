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
class PSIrivenIPV4Utils{

    Static [int64]ip2long ([String]$ip)
    { 
      $octets = $ip.split(".") 
      $octets[0] = [int64]$octets[0]
      $octets[1] = [int64]$octets[1]
      $octets[2] = [int64]$octets[2]
      $octets[3] = [int64]$octets[3]
      return ($octets[0]*16777216 +$octets[1]*65536 +$octets[2]*256 +$octets[3]) 
    } 
 
    Static [system.String]long2ip([int64]$int)
    { 
      return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
    } 

    Static [System.Collections.ArrayList]GetIPAddressRange([String]$IPRange, $PadStart, $PadEnd){ 
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
          $FirstAddress = [PSIrivenIPV4Utils]::ip2long($Start.ipaddresstostring)
          $LastAddress = [PSIrivenIPV4Utils]::ip2long($End.ipaddresstostring)
        }
        else {
          if(([int]$Matches.max -lt 1) -Or ([int]$Matches.max -gt 32)){ write-host "invalid subnet"; exit}
          $maskaddr = [Net.IPAddress]::Parse(([PSIrivenIPV4Utils]::long2ip([convert]::ToInt64(("1"*$Matches.max+"0"*(32-$Matches.max)),2))))
          $networkaddr = new-object net.ipaddress ($maskaddr.address -band $Start.address)
          $broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address)) 
          $FirstAddress = [PSIrivenIPV4Utils]::ip2long($networkaddr.ipaddresstostring) + $PadStart 
          $LastAddress = [PSIrivenIPV4Utils]::ip2long($broadcastaddr.ipaddresstostring)  - $PadEnd
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

    Static [System.Collections.ArrayList]GetIPAddressRange([String]$IPRange, $PadStart){
        return [PSIrivenIPV4Utils]::GetIPAddressRange($IPRange,$PadStart,$null)
    }

    Static [System.Collections.ArrayList]GetIPAddressRange([String]$IPRange){
        return [PSIrivenIPV4Utils]::GetIPAddressRange($IPRange,$null,$null)
    }

}




