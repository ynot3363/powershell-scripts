param(
  [Parameter(Mandatory)]
  [string]$ImagePath
)

if(not(Test-Path $ImagePath)) {
  Write-Error "Image path '$ImagePath' does not exist."
  exit 1

try {
    $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $base64String = [System.Convert]::ToBase64String($bytes)
    Write-Output $base64String

    $outputPath = [System.IO.Path]::ChangeExtension($ImagePath, ".b64.txt")
    Set-Content -Path $outputPath -Value $base64String
    Write-Output "Base64 string saved to '$outputPath'"

    Invoke-Item $outputPath
}
catch {
    Write-Error "Error encoding image: $_"
}