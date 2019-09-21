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
class PSIrivenMenu{

    static 
    hidden Make([array]$menuItems, [int]$menuPosition,[string]$menuTitle, [bool]$addExit = $false)
    {
        if(-not($host)){ $host = Get-Host}
        $fcolor = $host.UI.RawUI.ForegroundColor
        $bcolor = $host.UI.RawUI.BackgroundColor
        $l = $menuItems.length + 1
        Clear-Host
        $menuwidth = $menuTitle.length + 4
        Write-Host " " -NoNewLine
        Write-Host ("*" * $menuwidth) -fore $fcolor -back $bcolor
        Write-Host " " -NoNewLine
        Write-Host "* $menuTitle *" -fore $fcolor -back $bcolor
        Write-Host " " -NoNewLine
        Write-Host ("*" * $menuwidth) -fore $fcolor -back $bcolor
        Write-Host ""
        Write-debug "L: $l MenuItems: $menuItems MenuPosition: $menuposition"
        for ($i = 0; $i -le $l;$i++) 
        {
            if($addExit)
            {
                if ("$($menuItems[$i])" -eq "$($menuItems[-1])") 
                { 
                    Write-Host "`r`n " -NoNewLine
                    Write-Host ("*" * $menuwidth) -fore $fcolor -back $bcolor
                }
            }
            Write-Host " " -NoNewLine
            if ($i -eq $menuPosition) 
            { 
                if($addExit -and ("$($menuItems[$i])" -eq "$($menuItems[-1])"))
                {Write-Host "$($menuItems[$i])" -fore "red" -back $fcolor}
                else{Write-Host "$($menuItems[$i])" -fore $bcolor -back $fcolor}
            } 
            else 
            {  
                if($addExit -and ("$($menuItems[$i])" -eq "$($menuItems[-1])"))
                {Write-Host "$($menuItems[$i])" -fore "yellow" -back $bcolor}
                else{Write-Host "$($menuItems[$i])" -fore $fcolor -back $bcolor }
            }
        }

    }

    static [string]Generate( [array]$menuItems, [string]$menuTitle = "MENU", [bool]$addExit = $true) {

        if($addExit){$menuItems += 'Exit'}
        $vkeycode = 0
        $pos = 0
        if(-not($host)){ $host = Get-Host}
        [PSIrivenMenu]::Make($menuItems, $pos, $menuTitle, $addExit)
        While ($vkeycode -ne 13) {
            $press = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown")
            $vkeycode = $press.virtualkeycode
            Write-host "$($press.character)" -NoNewLine
            If (($vkeycode -eq 38) -Or
               ($vkeycode -eq 107)) {$pos--}
            If (($vkeycode -eq 40) -OR
               ($vkeycode -eq 8) -OR
               ($vkeycode -eq 9) -OR
               ($vkeycode -eq 109)) { $pos++}
            if ($pos -lt 0) {$pos = 0}
            if ($pos -ge $menuItems.length) {$pos = $menuItems.length -1}
            [PSIrivenMenu]::Make($menuItems, $pos, $menuTitle, $addExit)
        }
       If ($addExit -and ($($menuItems[$pos]) -eq 'Exit')){return ''}
       #Else {Write-Output $($menuItems[$pos])} 
       return $($menuItems[$pos])
    }

    static [string] Generate( [array]$menuItems, [string]$menuTitle = "MENU") {
        return [PSIrivenMenu]::Generate($menuItems, $menuTitle, $true)
    }
}