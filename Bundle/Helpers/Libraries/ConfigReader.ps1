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
class PSIrivenConfig{

    [ValidateNotNullOrEmpty()][String] 
    hidden $RuntimeDriver;
    [ValidateNotNullOrEmpty()][String] 
    hidden $ConfigFileFolder;
    [ValidateNotNullOrEmpty()][HashTable]
    hidden $Configuration;
    [ValidateNotNullOrEmpty()][String]
    hidden $Delimiter=',';
    [ValidateNotNullOrEmpty()][array] 
    hidden $Headers
    [ValidateNotNullOrEmpty()][array] 
    hidden $AcceptedDrivers = @('json','csv','ini','xml') 

    PSIrivenConfig([System.IO.FileInfo]$Folder, [String]$Driver)
    {
            $this.ConfigFileFolder = $Folder
            if(-not($this.AcceptedDrivers -contains "$Driver")){$Driver = 'json'}
            $this.RuntimeDriver = $Driver  
    }
    PSIrivenConfig([System.IO.FileInfo]$Folder)
    {
        $this.ConfigFileFolder = $Folder
        $this.RuntimeDriver = 'json' 
    }

    [HashTable]GetParams()
    {
        return [HashTable]$this.Configuration 
    }
    
    [void]Parse([string]$Filename)
    {
        try {
            $FileObject = Get-ChildItem  -Path "$($this.ConfigFileFolder)" -Filter "$FileName.$($this.RuntimeDriver)"
            $FileObject|foreach-object{
                $filePath = (Join-Path "$($this.ConfigFileFolder)" "$($_.Name)")
                switch ($filePath){
                    {$filePath -match '.csv'}{ 
                         $content = Get-Content -Path $filePath -Raw -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
                        if(-not($this.Header)){
                            $config = (ConvertFrom-Csv -InputObject $content -Delimiter $($this.Delimiter) -NoTypeInformation -ErrorAction:Stop -WarningAction:SilentlyContinue)
                        }
                        else {
                            $config = (ConvertFrom-Csv -InputObject $content -Delimiter $($this.Delimiter) -Header $($this.Header) -NoTypeInformation -ErrorAction:Stop -WarningAction:SilentlyContinue)
                        }
                        break;
                    }
                    {$filePath -match '.json'}{
                         $content = Get-Content -Path $filePath -Raw -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
                        $config = ($content|ConvertFrom-Json -ErrorAction:Stop -WarningAction:SilentlyContinue)
                        break;
                    }
                    #{($filePath -match '.yaml') -or ($filePath -match '.yml')}{
                    #    $streamReader = [System.IO.File]::OpenText($filePath)
                    #    $yamlStream = New-Object YamlDotNet.RepresentationModel.YamlStream
#
                    #    $yamlStream.Load([System.IO.TextReader] $streamReader)
                    #    $streamReader.Close()
                    #    $config = $yamlStream.Documents[0]
                    #    #$config = ($content|ConvertFrom-Yaml -ErrorAction:Stop -WarningAction:SilentlyContinue)
                    #    break;
                    #}
                    {$filePath -match '.xml'}{
                        $config = ($content|ConvertFrom-Xml -NoTypeInformation -Depth 100 -ErrorAction:Stop -WarningAction:SilentlyContinue)
                        break;
                    }
                    {$filePath -match '.ini'}{
                        $config = Get-Content -Path $filePath -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
                        break;
                    }
                    Defaut {
                        throw 'Error: No configuration File Found.'
                        break;
                    }
                }
                    $this.Configuration += $this.NormalizeDatas($config) 
            }  
        }
        catch [Exception]{
             write-error -Message $_.Exception.Message  -EA Stop
        }      
    }
 
    [HashTable]
    hidden NormalizeDatas([PSCustomObject]$Datas) {
        $Output = New-Object System.Collections.Specialized.OrderedDictionary    

          if($Datas -is [System.Array])
          {
            #############             
            $SectionDatas = New-Object System.Collections.Specialized.OrderedDictionary
            $Section = "default"
            switch -regex ($Datas)
            {
                '^\[(?<section>.+)\]$'
                {
                    if ($SectionDatas.Count -gt 0) {
                        $Output.Add($Section, $SectionDatas)
                        $SectionDatas = New-Object System.Collections.Specialized.OrderedDictionary   
                    }
                    $Section = $Matches['Section']  
                }
                '(?<key>.+?)\s*=\s*(?<value>.*)' { $SectionDatas.Add($Matches['Key'], $Matches['Value']) }
                '^(\s+)?;|^\s*$' {} #empty lines and comment  
                '(?<key>\;)(?<value>.*)' { $SectionDatas.Add($Matches['Key'], $Matches['Value']) }
                default { throw "Unidentified: $_" }
            }
            if ($Output.Keys -notcontains $Section) { $Output.Add($Section, $SectionDatas) }
            #############          
          }
          else {
            #############      
                $Datas.PSObject.Properties| ForEach-Object {
                    $itemName = $_.Name
                    $itemvalue = $_.Value
                    if($itemvalue -is [System.Management.Automation.PSCustomObject])
                    {
                        $Output.Add($itemName, $this.NormalizeDatas($itemvalue))
                    }
                    elseif ($itemvalue -is [System.Object[]]){
                        $list =  New-Object 'System.Collections.Generic.List[String]'
                        $itemvalue | ForEach-Object {
                            $list.Add((Get-NamespacedMembers -Datas $_)) | Out-Null
                        }
                        $Output.Add($itemName, $list);
                    }
                    else { $Output.Add($itemName, $itemvalue);}
                }
            ############
          }
        return $Output
    }


} ##### FIN DE LA CLASSE ######