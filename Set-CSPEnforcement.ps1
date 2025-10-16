param(
    [Parameter(Mandatory)]
    [string]$TenantAdminUrl,

    [Parameter(Mandatory)]
    [bool]$EnableContentSecurityPolicy = $true
)

$Module = Get-Module -Name PnP.PowerShell -ListAvailable | Select-Object Name,Version
if ($null -eq $Module) {
  Write-Host "PnP.PowerShell module not found. Installing..."
  Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force
} else {
  Write-Host "PnP.PowerShell module found. Version: $($Module.Version)"
}

Connect-PnPOnline $TenantAdminUrl -Interactive
$CSPSetting = Get-PnPTenant | Select-Object ContentSecurityPolicyEnforcement

if($CSPSetting.ContentSecurityPolicyEnforcement -eq $EnableContentSecurityPolicy) {
    Write-Host "Content Security Policy is already set to $EnableContentSecurityPolicy. No changes needed."
} else {
    Write-Host "Changing Content Security Policy setting to $EnableContentSecurityPolicy."
    Set-PnPTenant -ContentSecurityPolicyEnforcement $EnableContentSecurityPolicy
}