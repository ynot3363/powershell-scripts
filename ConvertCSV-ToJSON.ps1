param(
  [Parameter(Mandatory)]
  [string]$csvFilePath,

  [Parameter(Mandatory)]
  [string]$jsonFilePath
)

$csvData = Import-Csv -Path $csvFilePath
$jsonData = $csvData | ConvertTo-Json -Depth 10 

Set-Content -Path $jsonFilePath -Value $jsonData

Write-Host "Converted CSV data from '$csvFilePath' to JSON format and saved to '$jsonFilePath'."

Invoke-Item $jsonFilePath