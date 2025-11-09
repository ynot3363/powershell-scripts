param(
  [Parameter(Mandatory)]
  [string]$SourceSiteUrl,

  [Parameter(Mandatory)]
  [string]$TargetSiteUrl
)

$Module = Get-Module -Name PnP.PowerShell -ListAvailable | Select-Object Name,Version
if ($Module -eq $null) {
  Write-Host "PnP.PowerShell module not found. Installing..."
  Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force
} else {
  Write-Host "PnP.PowerShell module found. Version: $($Module.Version)"
}

try {
    #Connect to SharePoint Online site
    Connect-PnPOnline $SourceSiteURL -Interactive 

    Write-Host -ForegroundColor Cyan "Retrieving navigation nodes from source hub site..."
    $sourceNavigationNodes = @();
    $topNavigationNodes = Get-PnPNavigationNode -Location "TopNavigationBar"

    foreach ($node in $topNavigationNodes){
        $tempNode = @{
            Title = $node.Title
            Url = if($node.Url[0] -eq "/"){
                $SourceSiteUrl + $node.Url
            } else {
                $node.Url   
            }
            IsExternal = $node.IsExternal
            Children = @()
        }

        $childNodes = Get-PnPNavigationNode -Id $node.Id

        foreach( $child in $childNodes ){
            $tempChildNode = @{
                Title = $child.Title
                Url = if($child.Url[0] -eq "/"){
                    $SourceSiteUrl + $child.Url
                } else {
                    $child.Url   
                }
                IsExternal = $child.IsExternal
                Children = @()
            }
            
            $finalChildNodes = Get-PnPNavigationNode -Id $child.Id

            foreach( $finalChild in $finalChildNodes ){
                $tempFinalChildNode = @{
                    Title = $finalChild.Title
                    Url = if($finalChild.Url[0] -eq "/"){
                        $SourceSiteUrl + $finalChild.Url
                    } else {
                        $finalChild.Url   
                    }
                    IsExternal = $finalChild.IsExternal
                }
                $tempChildNode.Children += $tempFinalChildNode
            }
            $tempNode.Children += $tempChildNode
        }
        $sourceNavigationNodes += $tempNode
    }
}
catch {
    Write-Host -ForegroundColor Red "Error connecting to source site and retrieving navigation: $_"
}

try{
    Connect-PnPOnline $TargetSiteURL -Interactive

    Write-Host -ForegroundColor Cyan "Adding navigation nodes to target hub site..."

    foreach($node in $sourceNavigationNodes){
        $newNode = Add-PnPNavigationNode -Title $node.Title -Url $node.Url -Location "TopNavigationBar" -External $node.IsExternal

        foreach($child in $node.Children){
            $newChildNode = Add-PnPNavigationNode -Title $child.Title -Url $child.Url -Location "TopNavigationBar" -External $child.IsExternal -ParentNode $newNode.Id

            foreach($finalChild in $child.Children){
                Add-PnPNavigationNode -Title $finalChild.Title -Url $finalChild.Url -Location "TopNavigationBar" -External $finalChild.IsExternal -ParentNode $newChildNode.Id
            }
        }
    }

    Write-Host -ForegroundColor Green "Hub site navigation copied successfully from '$SourceSiteUrl' to '$TargetSiteUrl'."
}
catch {
    Write-Host -ForegroundColor Red "Error connecting to target site and adding navigation: $_"
}