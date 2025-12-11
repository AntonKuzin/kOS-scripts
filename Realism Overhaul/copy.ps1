$targetDirectory = "E:\Games\Kerbal Space Program RSS\Ships\Script"
Copy-Item -Path "$PSScriptRoot\*" -Destination $targetDirectory -Include "*.ks"  -Recurse
Write-Host $(Get-Date -DisplayHint Time)