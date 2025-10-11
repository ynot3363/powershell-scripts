param(
  [Parameter(Mandatory)]
  [string]$HubSiteUrl,

  [Parameter(Mandatory)]
  [string]$TenantAdminUrl,

  [Parameter(Mandatory)]
  [string]$ExportFilePath
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

$SitesInHub | Select-Object Title, Url | Export-Csv -Path $ExportFilePath -NoTypeInformation -Encoding UTF8
