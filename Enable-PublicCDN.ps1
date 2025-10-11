param(
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

$PublicCDN = Get-PnPTenantCdnEnabled -CdnType Public

if($PublicCDN -eq $true){
    Write-Host "Public CDN is already enabled."
    $Origins = Get-PnPTenantCdnOrigin -CdnType Public

    # Custom Business Logic to Remove site assets as an origin for the CDN
    foreach($Origin in $Origins){
        if($Origin -eq "/siteassets"){
            Write-Host "Removing the */siteassets origin..."
            Remove-PnPTenantCdnOrigin -CdnType Public -Origin $Origin -Force
        }
    }
} else {
    Write-Host "Enabling Public CDN..."
    Set-PnPTenantCdnEnabled -CdnType Public -Enable $true -NoDefaultOrigins
    Write-Host "Public CDN has been enabled."
    Write-Host "Origins:"
    Get-PnPTenantCdnOrigin -CdnType Public
}