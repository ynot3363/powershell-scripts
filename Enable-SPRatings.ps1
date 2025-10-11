param(
  [Parameter(Mandatory)]
  [string]$SiteUrl,

  [Parameter(Mandatory)]
  [string]$ListName,

  [ValidateSet('Ratings','Likes','')] # '' disables
  [string]$RatingsType = 'Likes'
)

$Module = Get-Module -Name PnP.PowerShell -ListAvailable | Select-Object Name,Version
if ($Module -eq $null) {
  Write-Host "PnP.PowerShell module not found. Installing..."
  Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force
} else {
  Write-Host "PnP.PowerShell module found. Version: $($Module.Version)"
}
 
#Connect to SharePoint Online site
Connect-PnPOnline $SiteURL -Interactive 
 
# 1) Ensure Ratings infrastructure feature is enabled at Site scope
#    (Social/ratings plumbing – required for Rating Settings to light up)
if(Get-PnPFeature -Identity 915c240e-a6cc-49b8-8b2c-0bff8b553ed3 -Scope Site){
    Write-Host "$([char]0x2714) Ratings infrastructure feature already enabled at Site scope" -ForegroundColor Green
} else {
    Write-Host "-- Enabling Ratings infrastructure feature at Site scope..."
    Enable-PnPFeature -Identity 915c240e-a6cc-49b8-8b2c-0bff8b553ed3 -Scope Site -Force
}


# 2) Resolve list and its default view
$list = Get-PnPList -Identity $ListName -Includes RootFolder, RootFolder.Properties -ErrorAction Stop
$defaultView = (Get-PnPView -List $list -Includes ViewFields | Where-Object { $_.DefaultView })

# 3) Add built-in Ratings/Likes site columns to the list (if not already added)
#    These are the well-known field IDs in SPO
$ratingFieldIds = @(
  [Guid]'5a14d1ab-1513-48c7-97b3-657a5ba6c742', # AverageRating
  [Guid]'b1996002-9167-45e5-a4df-b2c41c6723c7', # RatingCount
  [Guid]'4D64B067-08C3-43DC-A87B-8B8E01673313', # RatedBy
  [Guid]'434F51FB-FFD2-4A0E-A03B-CA3131AC67BA', # Ratings (the 0-5 control)
  [Guid]'6E4D832B-F610-41a8-B3E0-239608EFDA41', # LikesCount
  [Guid]'2CDCD5EB-846D-4f4d-9AAF-73E8E73C7312'  # LikedBy
)

Write-Host "-- Ensuring rating fields are added to list '$ListName'..." 

foreach ($fid in $ratingFieldIds) {
  try {
    Add-PnPField -List $list -Field $fid -ErrorAction Stop | Out-Null
  } catch {
    # If already added, Add-PnPFieldToList throws; ignore duplicates.
  }
}

# 4) Tidy the default view based on desired mode
#    - Ratings  : show AverageRating, hide LikesCount
#    - Likes    : show LikesCount, hide AverageRating
#    - Disabled : hide both
function Ensure-ViewHasField {
  param([string]$fieldInternalName, [bool]$present)
  $has = ($defaultView.ViewFields -contains $fieldInternalName)
  if ($present -and -not $has)   { $defaultView.ViewFields.Add($fieldInternalName) | Out-Null }
  if (-not $present -and $has)   { $defaultView.ViewFields.Remove($fieldInternalName) | Out-Null }
}

switch ($RatingsType) {
  'Ratings' {
    Ensure-ViewHasField -fieldInternalName 'AverageRating'  -present $true
    Ensure-ViewHasField -fieldInternalName 'LikesCount'     -present $false
    Ensure-ViewHasField -fieldInternalName 'LikedBy'        -present $false
  }
  'Likes' {
    Ensure-ViewHasField -fieldInternalName 'LikesCount'     -present $true
    Ensure-ViewHasField -fieldInternalName 'LikedBy'        -present $true
    Ensure-ViewHasField -fieldInternalName 'AverageRating'  -present $false
  }
  default {
    Ensure-ViewHasField -fieldInternalName 'AverageRating'  -present $false
    Ensure-ViewHasField -fieldInternalName 'LikesCount'     -present $false
    Ensure-ViewHasField -fieldInternalName 'LikedBy'        -present $false
  }
}

Write-Host "-- Updating default view '$($defaultView.Title)' with the appropriate fields..." 

$fields = @()
foreach ($f in $defaultView.ViewFields) { $fields += $f }
Set-PnPView -List $ListName -Identity $defaultView.Title -Fields $fields | Out-Null

# 5) Set the list’s RootFolder property bag to choose Likes vs Ratings
#    (This is what actually flips the UI “Rating settings”)

Write-Host "-- Setting the list's Ratings setting to '$RatingsType'..." 

if ($RatingsType -in @('Ratings','Likes')) {
  Set-PnPPropertyBagValue -Folder $list.Url -Key 'Ratings_x005f_VotingExperience' -Value $RatingsType -Force | Out-Null
  # Set unescaped variant too (harmless if unused)
  Set-PnPPropertyBagValue -Folder $list.Url -Key 'Ratings_VotingExperience'       -Value $RatingsType -Force | Out-Null
} else {
  # Disabling: clear key(s)
  Remove-PnPPropertyBagValue -Folder $list.Url -Key 'Ratings_x005f_VotingExperience' -Force -ErrorAction SilentlyContinue | Out-Null
  Remove-PnPPropertyBagValue -Folder $list.Url -Key 'Ratings_VotingExperience'       -Force -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "$([char]0x2714) Ratings setting applied to '$ListName': '$RatingsType'" -ForegroundColor Green