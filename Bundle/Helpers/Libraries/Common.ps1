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
    class PSIrivenUtils{

        static AddNewLine()
        {
            Write-Host "`r`n" 
        }

        Static [Bool]Exists([string]$FilePath)
        {
            [bool]$found = (Test-Path $FilePath -ErrorAction SilentlyContinue)
            return [bool]$found
        }

        static
        [Bool] PropertyExists($Object, [String]$Property)
        {
             try {
                 if ($null -ne $Object[$Property]) {return $true}
                 return $false
             }
             catch [Exception]{
                 return $false
             }
             return $false
        }
        static
        [Bool] IsEmpty([string]$varname){
            if (Test-path "variable:$varname")
            { 
                $val=(gi "variable:$varname").value
                if ($val -is [bool]) {
                    return $false
                }
                else {
                    return [Bool]($val -eq '' -or $val -eq $null)
                } 
            }
            else
            { return $true }
        }

        Static [Bool]FileExists([string]$FilePath)
        {
           # if (-not([PSIrivenUtils]::isValidFilename($FilePath))) {return $false}
            [bool]$found = (Test-Path $FilePath -PathType Leaf -ErrorAction SilentlyContinue)
            return [bool]$found
        }


        Static [Bool]GetBoolean([string]$boolValue)
        {
            try{ 
                    if(-not($boolValue)) {$result = $false }
                    else {
                        [bool]$result = $true
                        switch ( $boolValue.ToLower() )
                        {
                            {($_ -eq 'true') -or ($_ -eq '1') -or ($_ -eq 1) -or ($_ -eq $true)} { [bool]$result = $true ; break  }
                            {($_ -eq 'false') -or ($_ -eq '0') -or ($_ -eq 0) -or ($_ -eq $false)} { [bool]$result = $false ; break  }
                            default { throw "Invalid Argument: $boolValue can not be converted to boolean!"  ; break }
                        }
                        
                    }
                    
            }
            catch [Exception]{
                 Write-Error $_.Exception.Message   -EA Stop 
            }
            return [bool]$result
        }


        Static [String]GetCurrentUser()
        {
            [string]$User = $(Get-WMIObject -class Win32_ComputerSystem | select username).username
            if(!$User){ [string]$User = [Environment]::UserName}
            return $User
        }


        Static [PSCustomObject] GetHardwareInfos(){
            $WmiObject = (Get-WmiObject Win32_OperatingSystem)

            $HwReport = New-Object -Type PSObject -Property ([ordered]@{
                Name = $WmiObject.PSComputerName
                Serial = $WmiObject.SerialNumber
                OS = $WmiObject.Caption
                OSLang = $WmiObject.OSLanguage
                PSComputerName = $WmiObject.PSComputerName
                Country = $WmiObject.CountryCode
                InstallDate = $WmiObject.InstallDate
                Architecture = $WmiObject.OSArchitecture
                Build = $WmiObject.BuildNumber 
                OSDrive = $WmiObject.SystemDrive
                ClassPath = $WmiObject.ClassPath
                Organization = $WmiObject.Organization
                Version = $WmiObject.Version
            })
            return $HwReport
        }

        Static [String] GetHashCode([String]$FilePath, [String]$Algorithm)
        {
            $Algorithm = $Algorithm.ToUpper();
            $AcceptedAlgos = @('MD5','RIPEMD160','SHA1','SHA256','SHA512','SHA384')
            if(-not($AcceptedAlgos -contains "$Algorithm")){$Algorithm = 'MD5'}
            $HashBuilder = New-Object System.Text.StringBuilder
            $algo = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm) 
           if([PSIrivenUtils]::FileExists($FilePath)){
               $stream = New-Object System.IO.FileStream($FilePath, [System.IO.FileMode]::Open)
               $algo.ComputeHash($stream) | % {[void] $HashBuilder.Append($_.ToString("x2"))}
               $stream.Dispose()
           }
           else{
                $algo.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($FilePath))|%{[Void]$HashBuilder.Append($_.ToString("x2"))} 
           }
            $Hash = $HashBuilder.ToString() 
            return $Hash
        } #end function


        Static [Bool] isValidFilename([String]$filename)
        {
            $IndexOfInvalidChar = $filename.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())
            if($IndexOfInvalidChar -eq -1){ return $true;}
            return $false;
        } #end function


        Static [void]MakeFile([System.IO.FileInfo]$Location,[string]$Filename)
        {
            if([PSIrivenUtils]::isValidFilename($Filename)){
                if([PSIrivenUtils]::NotExists($Location)){ [PSIrivenUtils]::MakeDirectory($Location)}
                $FilePath = (Join-Path $Location $Filename)
                if([PSIrivenUtils]::NotExists($FilePath))
                {
                    New-Item  -ItemType File -Path "$Location" -Name "$Filename" -Force:$true | Out-Null
                }
            }
        }


        Static [void]MakeDirectory([System.IO.FileInfo]$Directory)
        {
            if([PSIrivenUtils]::NotExists($Directory))
            {
              New-Item -ItemType Directory -Path "$Directory" -Force:$true | Out-Null
            }
        }

        Static [PSCustomObject]MergeObject([PSCustomObject]$FirstObject,[PSCustomObject]$SecondObject)
        {
            $Output = [Pscustomobject]@()
            $FirstObject.psobject.Properties| Foreach-Object{ $Output += @{$_.Name = $_.value}}
            $SecondObject.psobject.Properties| Foreach-Object{ $Output += @{$_.Name = $_.value}}
            return [Pscustomobject]$Output

        }        


        Static [Bool]NotExists([string]$FilePath)
        {
            [bool]$Notfound = -not([PSIrivenUtils]::Exists($FilePath))
            return [bool]$Notfound
        }

        Static [Bool]PathExists([System.IO.FileInfo]$Location)
        {
            return [PSIrivenUtils]::Exists($Location)
        }

        Static [String]StringReplace([String]$Variable, [String]$needle, [String]$replace)
        {
            if (-not ([string]::IsNullOrEmpty($Variable)) -and -not ([string]::IsNullOrEmpty($needle)))
            {
                return $($Variable.Replace("$needle", "$replace"))
            }
            return $Variable
        }
      
    } # CLASS END
