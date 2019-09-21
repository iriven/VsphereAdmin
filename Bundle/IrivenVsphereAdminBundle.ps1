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

class PSIrivenModule{

    static
    [Bool]Enable()
    {
        Write-Verbose ("Entered function : {0} " -f $MyInvocation.MyCommand)
        $ModuleName = "VMware.PowerCLI"
        if(($Global:PSVersionTable.PSVersion.Major -ge 5) -and ($Global:PSVersionTable.PSEdition -ne "Core"))
        { 
            Write-Verbose "PowerShell version greater/equal to 5 installed" 
            if (Get-Module -Name $ModuleName){Write-Verbose "PowerShell $ModuleName Module already loaded"; return $True}
            else
            {
                if (!(Get-Module -Name $ModuleName) -and (Get-Module -ListAvailable -Name $ModuleName))
                {
                    try{

                        Write-Verbose "loading the PowerShell $ModuleName Module..." 
                        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $true -confirm:$false
                        Import-Module -Name $ModuleName -ErrorAction Stop
                        Write-Verbose ("Exiting function : {0} " -f $MyInvocation.MyCommand)
                    }
                    catch # Try to install if loading fails
                    {
                        Write-Host "Failed initial loading of PowerShell $ModuleName Module..." 
                        Try
                        {
                          Write-Verbose "Checking/Installing NuGet package provider" 
                          if(!(Get-PackageProvider -ListAvailable -Name "NuGet")){Get-PackageProvider -Name NuGet -Force}
                            Write-Verbose "Setting PowerShell Gallery as trusted Repository" 
                            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                            Write-Verbose "Installing and loading the PowerShell $ModuleName Module..." 
                            Install-Module $ModuleName -scope CurrentUser -Force -ErrorAction Stop
                            Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $true -confirm:$false
                            Import-Module -Name $ModuleName -ErrorAction Stop
                        }
                        catch{Write-Host "ERROR: Cannot load or install the VMware PowerCLI Module. Please install manually." - ForegroundColor Red;return $false;exit 1}
                    }
                    Write-Verbose ("Exiting function : {0} " -f $MyInvocation.MyCommand)
                    return $True
                } # End if (!(Get-Module -Name "VMware.PowerCLI") -and (Get-Module -ListAvailable -Name "VMware.PowerCLI"))
            }
        } # End if(($Global:PSVersionTable.PSVersion.Major -ge 5) -and ($Global:PSVersionTable.PSEdition -ne "Core"))
        elseif(($Global:PSVersionTable.PSVersion.Major -ge 3)-and ($Global:PSVersionTable.PSVersion.Major -lt 5))
        {
            Write-Verbose "PowerShell version greater/equal to 3 but less than 5 installed" 
            $ModuleList = @(
                "VMware.VimAutomation.Core",
                "VMware.VimAutomation.Vds",
                "VMware.VimAutomation.Cloud",
                "VMware.VimAutomation.PCloud",
                "VMware.VimAutomation.Storage",
                "VMware.VimAutomation.HA",
                "VMware.VimAutomation.vROps",
                "VMware.VumAutomation",
                "VMware.VimAutomation.License",
                "VMware.VimAutomation.Cis.Core"
                )
            $Loaded = $False
            foreach($Module in $ModuleList)
            {
                if ((!(Get-Module -Name $Module)) -and (Get-Module -ListAvailable -Name $Module))
                { 
                    Write-Verbose "loading the $Module Module..." 
                    try
                    {
                        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $true -confirm:$false
                        Import-Module -Name $Module -ErrorAction Stop
                        $Loaded = $True 
                    }
                    catch {Write-Host "ERROR: Cannot load the $Module Module. Is VMware PowerCLI installed?" - ForegroundColor Red;return $false;exit 1} # Error out if loading fails
                } # End if ((!(Get-Module -Name $Module)) -and (Get-Module -ListAvailable -Name $Module)) 

                elseif ((!(Get-PSSnapin -Name $Module -ErrorAction SilentlyContinue)) -and (!(Get-Module -Name $Module)) -and ($Loaded -ne $True))
                { 
                    Write-Verbose "loading the $Module Snapin..." 
                    Try {Add-PSSnapin -PassThru $Module -ErrorAction Stop}
                    catch {Write-Host "ERROR: Cannot load the $Module Snapin or Module. Is VMware PowerCLI installed?" - ForegroundColor Red;return $false;exit 1} # Error out if loading fails
                }
            } # End foreach($Module in $ModuleList)
            Write-Verbose ("Exiting function : {0} " -f $MyInvocation.MyCommand)
            return $True
        }
        else{Write-Host "PowerShell version less than 3 installed!" - ForegroundColor Red;return $false;exit 1 }
        Write-Verbose ("Exiting function : {0} " -f $MyInvocation.MyCommand)
        return $true
    } # End function EnablePowercli

} #class end

try 
{
    [PSIrivenModule]::Enable() | Out-Null
  . (Join-Path $PSScriptRoot Helpers\IrivenPowercliHelpers.ps1)
  . (Join-Path $PSScriptRoot Vsphere\IrivenPowercliClassmap.ps1)
    $prefBackup = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
}
catch
{
    Write-Error $_.Exception.Message  -EA Stop 
}