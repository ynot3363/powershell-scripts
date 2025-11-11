$ManagedIdentityName = "YourManagedIdentityName"
$MSGraphAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph App ID
$AppRoles = @("AuditLog.Read.All","User.Read.All","User,EnableDisableAccount.All","Mail.Send.Shared")

Connect-MgGraph -Scopes "AppRoleAssignment.ReadWrite.All","Application.Read.All"

$ManagedIdentityServicePrincipal = Get-MgServicePrincipal -Filter "displayName eq '$ManagedIdentityName'"
if ($null -eq $ManagedIdentityServicePrincipal) {
    Write-Host -ForegroundColor Red "Managed Identity $($ManagedIdentityName) not found."
    exit
}

$GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$MSGraphAppId'"

if($null -eq $GraphServicePrincipal) {
    Write-Host -ForegroundColor Red "Microsoft Graph Service Principal not found."
    exit
}

foreach ($AppRole in $AppRoles) {
    $role = $GraphServicePrincipal.AppRoles | Where-Object { $_.Value -eq $AppRole -and $_.AllowedMemberTypes -contains "Application" -and $_.IsEnabled -eq $true }
    if ($null -eq $role) {
        Write-Host -ForegroundColor Yellow "App Role $($AppRole) not found or not enabled for applications."
        continue
    }

    $APIPermissionsAlreadyAssigned = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityServicePrincipal.Id | Where-Object { $_.AppRoleId -eq $role.Id -and $_.ResourceId -eq $GraphServicePrincipal.Id }

    if($APIPermissionsAlreadyAssigned) {
        Write-Host -ForegroundColor Green "App Role $($AppRole) is already assigned to Managed Identity $($ManagedIdentityName)."
    } else {
        $appRoleAssignment = @{
            principalId = $ManagedIdentityServicePrincipal.Id
            resourceId  = $GraphServicePrincipal.Id
            appRoleId   = $role.Id
        }

        try {
            New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityServicePrincipal.Id -BodyParameter $appRoleAssignment | Out-Null
            Write-Host -ForegroundColor Green "Successfully assigned App Role $($AppRole) to Managed Identity $($ManagedIdentityName)."
        } catch {
            Write-Host -ForegroundColor Red "Failed to assign App Role $($AppRole): $($_)"
        }
    }
}
