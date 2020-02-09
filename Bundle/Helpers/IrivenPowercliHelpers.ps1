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
if(!$PSScriptRoot){ $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
try
{
    . (Join-Path $PSScriptRoot 'Libraries\Common.ps1')
    . (Join-Path $PSScriptRoot 'Libraries\EventLogger.ps1') 
    . (Join-Path $PSScriptRoot 'Libraries\ConfigReader.ps1')   
    . (Join-Path $PSScriptRoot 'Libraries\Navigation.ps1')
    . (Join-Path $PSScriptRoot 'Libraries\IPV4Utilities.ps1')  
    . (Join-Path $PSScriptRoot 'Libraries\Forms.ps1')           
}
catch
{
    Write-Error $_.Exception.Message -EA Stop 
}