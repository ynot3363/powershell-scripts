param(
  [Parameter(Mandatory)]
  [string]$ExportFilePath
)

Connect-Entra

$ExportUsers = @();
$Users = Get-EntraUser -All;

foreach($User in $Users){
    $NewUser = [PSCustomObject]@{
        Id    = $User.objectId
        Name  = $User.displayName
        Email = $User.mail
    }
    $ExportUsers += $NewUser
}

$ExportUsers | Export-Csv -Path $ExportFilePath -NoTypeInformation -Encoding UTF8

Invoke-Item -Path $ExportFilePath