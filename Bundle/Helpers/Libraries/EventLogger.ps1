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
    class PSIrivenEvents{

        static writeLog([String]$Message,[String]$Level = 'info',[String]$LogFile){

                $timeStamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
                $Event = $null
                $color = 'Blue'
                Switch ($Level)
                {
                    'Warning' {$Event = ("[" + $timeStamp + "] -" + " WARNING" +": "); $color = 'Yellow'}
                    'Error' {$Event =  ("[" + $timeStamp + "] -" + " ERROR" +": "); $color = 'Red'}
                    default{$Event = ("[" + $timeStamp + "] -" + " INFORMATION" +": "); $color = 'Blue'}
                }        
                 Write-Host -NoNewline -ForegroundColor White "`r`n$Event"
                 Write-Host -ForegroundColor $color " $message "
                 If ($LogFile)
                 {
                    If (!(Get-Item $LogFile -ErrorAction SilentlyContinue)){ New-Item $LogFile -Force -ItemType File | Out-Null}
                    $statemnt = ($Event + $Message)
                    Write-Output $statemnt | Out-File -FilePath $LogFile -Append
                 }
        }

        static DisplayMessage([String]$message,[String]$color,[bool]$SameLine)
        {
            if (-not($color)) {$color = 'white' }
            if (-not($SameLine)) {$SameLine = $false }
            if($SameLine){Write-Host -NoNewline -ForegroundColor $color " $message "}
            else{Write-Host -ForegroundColor $color " $message" }  
        }

        static DisplayMessage([String]$message,[String]$color)
        {
            [PSIrivenEvents]::DisplayMessage($message,$color,$false)
        } 

        static DisplayMessage([String]$message)
        {
            [PSIrivenEvents]::DisplayMessage($message, 'white')
        }        

    } #CLASS END
