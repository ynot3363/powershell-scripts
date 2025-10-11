param(
  [Parameter(Mandatory)]
  [string]$ExportFolderPath,

  [Parameter(Mandatory)]
  [string]$EnvironmentId
)

$Module = Get-Module -Name Microsoft.PowerApps.Administration.PowerShell -ListAvailable | Select-Object Name,Version

if ($Module -eq $null) {
  Write-Host "Microsoft.PowerApps.Administration.PowerShell module not found. Installing..."
  Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser -Force
} else {
  Write-Host "Microsoft.PowerApps.Administration.PowerShell module found. Version: $($Module.Version)"
}

Import-Module Microsoft.PowerApps.Administration.PowerShell -Force

$TodaysDate = Get-Date -Format "yyyy-MM-dd"
$ExportPath = Join-Path -Path $ExportFolderPath -ChildPath "$($TodaysDate)-PowerAutomateFlows.csv"

Add-PowerAppsAccount
$Environment = Get-AdminPowerAppEnvironment -EnvironmentName $EnvironmentId
$EnvironmentName = $Environment.Name

$PowerAutomateFlows = Get-AdminFlow -EnvironmentName $EnvironmentName

$FlowDetails = @()

foreach($Flow in $PowerAutomateFlows){
    $FlowInfo = [PSCustomObject]@{
        DisplayName = $Flow.DisplayName
        EnvironmentName = $Flow.EnvironmentName
        Internal = $Flow.Internal
        CreatedBy = $Flow.CreatedBy
        CreatedTime = $Flow.CreatedTime
        FlowName = $Flow.FlowName
        LinkToFlow = "https://make.powerautomate.com/environments/$($Flow.EnvironmentName)/flows/$($Flow.FlowName)/details"
        Enabled = $Flow.Enabled
        LastModifiedTime = $Flow.LastModifiedTime
        UserType = $Flow.UserType
    }

    $FlowDetails += $FlowInfo
}

$FlowDetails | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-Host "Export completed. File saved to $ExportPath"

Invoke-Item -Path $ExportPath