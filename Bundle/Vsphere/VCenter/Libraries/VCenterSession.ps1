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
class PSIrivenVISession{

    [HashTable]
    hidden $Settings  = @{};

    [Bool] 
    hidden $UseCredentials = $true

    [ValidateNotNullOrEmpty()] 
    [String]
    hidden $vCLogin = 'Administrator@vsphere.local'

    [ValidateNotNullOrEmpty()] 
    [String]
    hidden $DbType = 'irivendb'

    [ValidateNotNullOrEmpty()]
    [ValidateSet('Fail','Warn','Prompt','Ignore')]
    [String]
    hidden $InvalidCertificate = 'ignore'

#/*
#- Fail (default)
#- Warn
#- Prompt
#- Ignore
#*/

    PSIrivenVISession([HashTable]$Config)
    {
        try {

            if (-not([PSIrivenUtils]::PropertyExists($Config,'Inventory')) -or `
                -not([PSIrivenUtils]::PropertyExists($Config,'Credentials'))) 
            {
                throw "Error: Can't initialize PSIrivenVISession Class; Invalid Configuration Data Given."
            }
            if(-not([PSIrivenUtils]::PropertyExists($Config.Credentials,'Login')) -or `
                -not($Config.Credentials.Login)){$Config.Credentials.Set_Item('Login',$this.vCLogin)}
            if(-not([PSIrivenUtils]::PropertyExists($Config.Credentials,'Persistent')))
            {$Config.Credentials.Set_Item('Persistent',$this.UseCredentials)}
            $Config.Credentials.Set_Item('Persistent',[PSIrivenUtils]::GetBoolean($Config.Credentials.Persistent))
            $pattern = "^(fail|ignore|prompt|warn)$"
            if(-not([PSIrivenUtils]::PropertyExists($Config.Credentials,'InvalidCertificateAction')))
            {$Config.Credentials.Set_Item('InvalidCertificateAction',$this.InvalidCertificate)}
            if(-not($Config.Credentials.InvalidCertificateAction -match $pattern)){
                throw "Error: Invalid value given for the Parameter InvalidCertificateAction. Expected value: fail|ignore|prompt|warn"
            }
            $this.Settings += $Config
        }
        catch [Exception]{
            write-error -Message $_.Exception.Message  -EA Stop
        }
    }

    static [Bool]isStarted()
    {
        [Bool]$started = $true
        if(-not($Global:DefaultVIServers)) { [Bool]$started = $false }
        return [Bool]$started;
    }

    Start()
    {
        Set-PowerCLIConfiguration -InvalidCertificateAction $this.Settings.Credentials.InvalidCertificateAction -Scope User -Confirm:$false| Out-Null
        $MenusItems = ($this.Settings.Inventory.GetEnumerator() | ForEach-Object{$_.Key}| sort-object)
        [String]$vCenterName = $([PSIrivenMenu]::Generate($MenusItems, "PLEASE CHOOSE THE VCENTER YOU WANT TO JOIN"))
        if (-not($vCenterName))
        {
          [PSIrivenEvents]::DisplayMessage('Exiting ','white', $true)
          [PSIrivenEvents]::DisplayMessage(("." * 20), 'white', $true)
          sleep 1 
          [PSIrivenEvents]::DisplayMessage("done!", "green")
          [PSIrivenUtils]::AddNewLine()
          Exit
        }
        $vCenterIPAddress = $($this.Settings.Inventory."$vCenterName")
        [String]$vCenterName = $vCenterName.ToUpper()
        [PSIrivenEvents]::DisplayMessage("Selected vCenter: ", 'white')
        [PSIrivenEvents]::DisplayMessage(("-" * 20), 'white')
        [PSIrivenEvents]::DisplayMessage("Name   :", 'white', $true)
        [PSIrivenEvents]::DisplayMessage("$vCenterName", "green")
        [PSIrivenEvents]::DisplayMessage("IpAddr :", 'white', $true)
        [PSIrivenEvents]::DisplayMessage("$vCenterIPAddress", "green")
        [PSIrivenUtils]::AddNewLine()
        [PSIrivenEvents]::DisplayMessage('Connecting to the selected vCenter. Please wait .....', 'yellow')
        if($this.Settings.Credentials.Persistent -eq $true)
        {
          $SYSUsername = [PSIrivenUtils]::GetCurrentUser()
          $Drive = [PSIrivenUtils]::GetHardwareInfos()| Select -ExpandProperty OSDrive
          $FileLocation = Join-Path $Drive $([PSIrivenUtils]::GetHashCode($([string]::join('', [PSIrivenUtils]::GetHardwareInfos())) + $($SYSUsername),'sha1'))
          $CredentialFile = Join-Path $FileLocation $([PSIrivenUtils]::GetHashCode($SYSUsername, 'md5') + '.' + $this.DbType)

          if(-not([PSIrivenUtils]::FileExists($CredentialFile)))
          {
              [PSIrivenUtils]::MakeDirectory($FileLocation)
              [bool]$InputFound = $false
              Do{
                  [PSIrivenEvents]::DisplayMessage('Enter the selected vCenter Password : ','green', $true)
                  $UserInput = Read-Host -AsSecureString
                  if($UserInput.Length -ne 0)
                  {
                      $Encryption = ConvertFrom-SecureString -SecureString $UserInput
                      $Encryption | Out-File $CredentialFile
                      $InputFound = $true
                  }
                }while(-not($InputFound))
                [PSIrivenUtils]::AddNewLine()
          }
          $securePassword = Get-Content $CredentialFile | ConvertTo-SecureString
          $credentials = New-Object System.Management.Automation.PSCredential ($this.Settings.Credentials.Login, $securePassword)

        } #End $PersistentLogin
        else { $credentials = Get-Credential -Message 'Enter the Selected vCenter Credentials.' }
        # Connect to vCenter
        Connect-VIServer -Server $vCenterIPAddress -Credential $credentials -EA Stop -WarningAction SilentlyContinue| Out-Null 
        if($? -eq $true){
          $vCenterInstanceIP = $global:defaultviserver | select -expandproperty name
          if($vCenterInstanceIP -eq $vCenterIPAddress)
          {
            [PSIrivenEvents]::DisplayMessage('Successfully Connected to vCenter Server: ', 'white', $true)
            [PSIrivenEvents]::DisplayMessage("$vCenterName - $vCenterIPAddress" , 'green')
            [PSIrivenUtils]::AddNewLine()
          } 
        }
    }

    static Close()
    {
        try{
            if(-not([PSIrivenVISession]::isStarted())){  throw 'Error: You are not currently connected to any vCenter servers.'}
            $vCenterIPAddress = $Global:DefaultVIServer
            $vCenterName = (get-datacenter|select -ExpandProperty Name)
            Disconnect-VIServer -Server $vCenterIPAddress -confirm:$false 
            if($? -eq $true)
            { 
                [PSIrivenUtils]::AddNewLine()
                [PSIrivenEvents]::DisplayMessage('Connection Closed to vCenter server: ', 'white', $true)
                [PSIrivenEvents]::DisplayMessage("$vCenterName - $vCenterIPAddress" , 'green')
                [PSIrivenUtils]::AddNewLine()
            }
            else {throw "Error: Unable to disconnect to vCenter: $vCenterIPAddress ."}

        }
        catch [Exception]{
            write-error -Message $_.Exception.Message  -EA Stop
        }
    }
}
#Export-ModuleMember -Function PSIrivenVISession
#Import-Module path\to\VCenterSession.psm1