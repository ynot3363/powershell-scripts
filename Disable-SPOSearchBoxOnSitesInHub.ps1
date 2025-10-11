param(
  [Parameter(Mandatory)]
  [string]$HubSiteUrl,

  [Parameter(Mandatory)]
  [string]$TenantAdminUrl
)

$Module = Get-Module -Name PnP.PowerShell -ListAvailable | Select-Object Name,Version
if ($Module -eq $null) {
  Write-Host "PnP.PowerShell module not found. Installing..."
  Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force
} else {
  Write-Host "PnP.PowerShell module found. Version: $($Module.Version)"
}

Connect-PnPOnline -Url $TenantAdminUrl -Interactive

$HubSite = Get-PnPHubSite -Identity $HubSiteUrl

if ($null -eq $HubSite) {
    Write-Host -ForegroundColor Red "The specified URL is not a valid Hub Site."
    exit
}

$AllSites = Get-PnPTenantSite -Detailed

$SitesInHub = $AllSites | Where-Object { $_.HubSiteId -eq $HubSite.Id }

if($SitesInHub.Count -eq 0) {
    Write-Host -ForegroundColor Yellow "No sites found in the specified Hub Site, $($HubSiteUrl)."
    exit
}

foreach ($Site in $SitesInHub) {
    Write-Host "Connecting to $($Site.Url)..."
    Connect-PnPOnline -Url $Site.Url -Interactive
    Write-Host -ForegroundColor Cyan "Site Title: $($Site.Title)"
    Write-Host -ForegroundColor Yellow "Disabling Search Box..."
    try{
        Set-PnPSearchSettings -SearchBoxInNavBar "Hidden" -Scope Site -Force
        Write-Host -ForegroundColor Green "Search Box Disabled Successfully."
    } catch{
        Write-Host -ForegroundColor Red "Failed to disable Search Box: $_"
    }
}