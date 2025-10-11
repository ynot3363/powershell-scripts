param(
  [Parameter(Mandatory)]
  [string]$SiteUrl,

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

Connect-PnPOnline $TenantAdminUrl -Interactive
Add-PnPSiteCollectionAppCatalog -Site $SiteUrl