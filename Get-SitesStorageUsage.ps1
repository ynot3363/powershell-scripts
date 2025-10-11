param(
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

$AllSites = Get-PnPTenantSite -Detailed
$SiteUsageData = @()
$Counter = 0

foreach($Site in $Sites){
    $Counter++
    Write-Progress -Activity "Collecting Site Usage Data" -Status "Processing site $Counter of $($AllSites.Count): $($Site.Url)" -PercentComplete (($Counter / $AllSites.Count) * 100)
    $SiteUsageData += [PSCustomObject]@{
        URL                           = $Site.Url
        Title                         = $Site.Title
        Description                   = $Site.Description
        Owner                         = $Site.Owner
        Template                      = $Site.Template
        StorageQuota                  = $Site.StorageQuota
        StorageMaximumLevel           = $Site.StorageMaximumLevel
        StorageUsageCurrent           = $Site.StorageUsageCurrent
        StorageQuotaWarningPercentage = $Site.StorageQuotaWarningLevel/$Site.StorageQuota
        ResourceQuota                 = $Site.ResourceQuota
        ResourceQuotaWarningLevel     = $Site.ResourceQuotaWarningLevel
        ResourceUsageAverage          = $Site.ResourceUsageAverage
        ResourceUsageCurrent          = $Site.ResourceUsageCurrent
        SharingCapability             = $Site.SharingCapability
        LockState                     = $Site.LockState
        LastModifiedDate              = $Site.LastContentModifiedDate
        SubsitesCount                 = $Site.Webscount
    }
}

$SiteUsageData | Export-Csv -Path $ExportFilePath -NoTypeInformation -Encoding UTF8
Write-Host "Site usage data exported to $ExportFilePath"

Invoke-Item $ExportFilePath