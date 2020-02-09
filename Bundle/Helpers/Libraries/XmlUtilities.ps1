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
class PSIrivenXMLUtils{

    [ValidateNotNullOrEmpty()][xml]
    hidden $XmlDocument;

    PSIrivenXMLUtils([System.IO.File]$XmlFile){
        [ xml ]$this.XmlDocument = Get-Content -Path $XmlFile
    }

    static Get-XmlNamespaceManager([string]$NamespaceURI = "")
    {
        # If a Namespace URI was not given, use the Xml document's default namespace.
        if ([string]::IsNullOrEmpty($NamespaceURI)) { $NamespaceURI = $this.XmlDocument.DocumentElement.NamespaceURI }	
        
        # In order for SelectSingleNode() to actually work, we need to use the fully qualified node path along with an Xml Namespace Manager, so set them up.
        [System.Xml.XmlNamespaceManager]$xmlNsManager = New-Object System.Xml.XmlNamespaceManager($this.XmlDocument.NameTable)
        $xmlNsManager.AddNamespace("ns", $NamespaceURI)
        return ,$xmlNsManager		# Need to put the comma before the variable name so that PowerShell doesn't convert it into an Object[].
    }

    static Get-XmlNode([string]$NodePath, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.')
    {
        $xmlNsManager = Get-XmlNamespaceManager -XmlDocument $this.XmlDocument -NamespaceURI $NamespaceURI
        [string]$fullyQualifiedNodePath = Get-FullyQualifiedXmlNodePath -NodePath $NodePath -NodeSeparatorCharacter $NodeSeparatorCharacter
        # Try and get the node, then return it. Returns $null if the node was not found.
        $node = $this.XmlDocument.SelectSingleNode($fullyQualifiedNodePath, $xmlNsManager)
        return $node
    }

    static Get-XmlNodes([string]$NodePath, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.')
    {
        $xmlNsManager = Get-XmlNamespaceManager -XmlDocument $this.XmlDocument -NamespaceURI $NamespaceURI
        [string]$fullyQualifiedNodePath = Get-FullyQualifiedXmlNodePath -NodePath $NodePath -NodeSeparatorCharacter $NodeSeparatorCharacter
        # Try and get the nodes, then return them. Returns $null if no nodes were found.
        $nodes = $this.XmlDocument.SelectNodes($fullyQualifiedNodePath, $xmlNsManager)
        return $nodes
    }

    static Get-XmlElementsTextValue([string]$ElementPath, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.')
    {
        # Try and get the node.	
        $node = Get-XmlNode -XmlDocument $this.XmlDocument -NodePath $ElementPath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter
        
        # If the node already exists, return its value, otherwise return null.
        if ($node) { return $node.InnerText } else { return $null }
    }

    static [void] Set-XmlElementsTextValue([string]$ElementPath, [string]$TextValue, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.')
    {
        # Try and get the node.	
        $node = Get-XmlNode -XmlDocument $this.XmlDocument -NodePath $ElementPath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter
        
        # If the node already exists, update its value.
        if ($node)
        { 
            $node.InnerText = $TextValue
        }
        # Else the node doesn't exist yet, so create it with the given value.
        else
        {
            # Create the new element with the given value.
            $elementName = $ElementPath.Substring($ElementPath.LastIndexOf($NodeSeparatorCharacter) + 1)
            $element = $this.XmlDocument.CreateElement($elementName, $this.XmlDocument.DocumentElement.NamespaceURI)		
            $textNode = $this.XmlDocument.CreateTextNode($TextValue)
            $element.AppendChild($textNode) > $null
            
            # Try and get the parent node.
            $parentNodePath = $ElementPath.Substring(0, $ElementPath.LastIndexOf($NodeSeparatorCharacter))
            $parentNode = Get-XmlNode -XmlDocument $this.XmlDocument -NodePath $parentNodePath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter
            
            if ($parentNode)
            {
                $parentNode.AppendChild($element) > $null
            }
            else
            {
                throw "$parentNodePath does not exist in the xml."
            }
        }
    }

    static Get-XmlElementsAttributeValue([string]$ElementPath, [string]$AttributeName, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.')
    {
        # Try and get the node. 
        $node = Get-XmlNode -XmlDocument $this.XmlDocument -NodePath $ElementPath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter
        
        # If the node already exists, return its value, otherwise return null.
        if ($node -and $node.$AttributeName) { return $node.$AttributeName } else { return $null }
    }

    static [void] Set-XmlElementsAttributeValue([string]$ElementPath, [string]$AttributeName, [string]$AttributeValue, [string]$NamespaceURI = "", [string]$NodeSeparatorCharacter = '.')
    {
        # Try and get the node. 
        $node = Get-XmlNode -XmlDocument $this.XmlDocument -NodePath $ElementPath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter
        
        # If the node already exists, create/update its attribute's value.
        if ($node)
        { 
            $attribute = $this.XmlDocument.CreateNode([System.Xml.XmlNodeType]::Attribute, $AttributeName, $NamespaceURI)
            $attribute.Value = $AttributeValue
            $node.Attributes.SetNamedItem($attribute) > $null
        }
        # Else the node doesn't exist yet, so create it with the given attribute value.
        else
        {
            # Create the new element with the given value.
            $elementName = $ElementPath.SubString($ElementPath.LastIndexOf($NodeSeparatorCharacter) + 1)
            $element = $this.XmlDocument.CreateElement($elementName, $this.XmlDocument.DocumentElement.NamespaceURI)
            $element.SetAttribute($AttributeName, $NamespaceURI, $AttributeValue) > $null
            
            # Try and get the parent node.
            $parentNodePath = $ElementPath.SubString(0, $ElementPath.LastIndexOf($NodeSeparatorCharacter))
            $parentNode = Get-XmlNode -XmlDocument $this.XmlDocument -NodePath $parentNodePath -NamespaceURI $NamespaceURI -NodeSeparatorCharacter $NodeSeparatorCharacter
            
            if ($parentNode)
            {
                $parentNode.AppendChild($element) > $null
            }
            else
            {
                throw "$parentNodePath does not exist in the xml."
            }
        }
    }


}