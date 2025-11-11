<# Runbook: Disable inactive Guest accounts after N days (daily)
   Auth: Managed Identity (app-only)
   Graph perms (Application): AuditLog.Read.All, User.Read.All, User.EnableDisableAccount.All, Mail.Send
   License: Entra ID P1/P2 required to read signInActivity
#>

param(
  [int]$InactivityDays = 90,                            # default is 90 but we can scale it up or down if we want
  [bool]$Enforce = $false,                              # actually disable users or run in a report only mode
  [string]$StorageAccountName = "guestaccountreports",  # e.g. "guestaccountreports"
  [string]$StorageContainerName = "inactive-guests",    # existing container, e.g. inactive-guests
  [string]$ReportPrefix = "InactiveGuestsReport",       # file prefix
  [string]$Sender = "noreply@anthonyepoulin.com",       # send emails from
  [string[]]$To,                                        # e.g. ["anthony.poulin@anthonyepoulin.com"]
  [string[]]$Cc                                         # e.g. ["anthony.poulin@anthonyepoulin.com"]
)

# --- Graph Modules ---
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop

# --- Connect with Managed Identity ---
Connect-MgGraph -Identity | Out-Null

# --- Parameters & helpers ---
$thresholdUtc = (Get-Date).ToUniversalTime().AddDays(-$InactivityDays)
$select = "id,displayName,userPrincipalName,accountEnabled,userType,signInActivity"
$filter = "userType eq 'Guest' and accountEnabled eq true and externalUserState eq 'Accepted'" # Criteria is that the user type must be Guest, their account must be enabled, and the state of their invitation must be accepted.

# --- Pull enabled Guests with signInActivity (max pagesize 500 when selecting it). ---
$enabledGuests = Get-MgUser `
  -Property $select `
  -Filter  $filter `
  -ConsistencyLevel eventual `
  -PageSize 500 -All

$targets = $enabledGuests | Where-Object {
  ($_.SignInActivity.LastSuccessfulSignInDateTime -lt $thresholdUtc) -or ($_.SignInActivity.LastSignInDateTime -lt $thresholdUtc) -or ($_.SignInActivity.LastNonInteractiveSignInDateTime -lt $thresholdUtc)
} | Sort-Object -Property Id -Unique

# --- Build report (in temp path) ---
$report = $targets | Select-Object `
  Id, DisplayName, UserPrincipalName, UserType, AccountEnabled,
  @{N='LastSuccessfulSignInDateTime';E={$_.SignInActivity.LastSuccessfulSignInDateTime}},
  @{N='LastSignInDateTime';E={$_.SignInActivity.LastSignInDateTime}},
  @{N='LastNonInteractiveSignInDateTime';E={$_.SignInActivity.LastNonInteractiveSignInDateTime}}

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$filename = "$ReportPrefix-$stamp.csv"
$tmpPath = Join-Path $env:TEMP $filename
$report | Export-Csv -Path $tmpPath -NoTypeInformation -Encoding UTF8
Write-Output "Report generated: $tmpPath  Count=$($report.Count)"

# --- Enforcement (optional) ---
if ($Enforce) {
  Write-Output "Enforcement ON: disabling $($report.Count) account(s)..."
  foreach ($u in $targets) {
    try {
      Update-MgUser -UserId $u.Id -AccountEnabled:$false
      Write-Output "Disabled: $($u.UserPrincipalName)"
    } catch {
      Write-Warning "Failed: $($u.UserPrincipalName) -> $($_.Exception.Message)"
    }
  }
  Write-Output "Enforcement complete."
} else {
  Write-Output "Dry run only. Re-run with -Enforce to disable these accounts."
}

# --- Email the report (attachment) ---
$toRecipients = @(); foreach ($addr in $To) { if ($addr) { $toRecipients += @{ emailAddress = @{ address = $addr } } } }
$ccRecipients = @(); foreach ($addr in ($Cc | Where-Object { $_ })) { $ccRecipients += @{ emailAddress = @{ address = $addr } } }
$subjectAppend = "ReportOnly"
if($Enforce) { $subjectAppend = "Enforced"}
$subject = "Inactive Guests Report – $(Get-Date -Format 'yyyy-MM-dd') - $($subjectAppend)"
$bodyHtml = @"
<p>Attached is today’s inactive guest user report (total: <b>$($report.Count)</b>).</p>
"@

# Attach the CSV
$bytes = [System.IO.File]::ReadAllBytes($tmpPath)
$base64 = [Convert]::ToBase64String($bytes)
$attachment = @{
  "@odata.type" = "#microsoft.graph.fileAttachment"
  name          = $filename
  contentType   = "text/csv"
  contentBytes  = $base64
}

$payload = @{
  message = @{
    subject      = $subject
    body         = @{ contentType = "HTML"; content = $bodyHtml }
    toRecipients = $toRecipients
    ccRecipients = $ccRecipients
    attachments  = @($attachment)
  }
  saveToSentItems = $true
} | ConvertTo-Json -Depth 8

Write-Output $payload

Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$Sender/sendMail" -Body $payload -ContentType "application/json"
Write-Output "Email sent from $Sender to $($To -join ', ')"

# --- The following section is to store the report in Azure Blob Storage so we can reference them if needed ---
# --- Azure Modules ---
Import-Module Az.Accounts -Force
Import-Module Az.Storage  -Force

# --- Sign in to Azure with MI for data-plane access ---
Connect-AzAccount -Identity | Out-Null

# --- Build a Storage context with the *connected account* (no keys, no RG needed) ---
$stCtx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount -ErrorAction Stop

# --- Ensure container exists (409 if exists is fine) ---
try { New-AzStorageContainer -Name $StorageContainerName -Context $stCtx -ErrorAction Stop | Out-Null } catch {}

# --- Upload file ---
Set-AzStorageBlobContent -File $tmpPath -Container $StorageContainerName -Blob $filename -Context $stCtx -Force | Out-Null
$fileUrl = "https://$StorageAccountName.blob.core.windows.net/$StorageContainerName/$blob"
Write-Output "Uploaded to: $fileUrl"