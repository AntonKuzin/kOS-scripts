$stockOnly = @(
    "enginesData.ks",
    "test.ks"
)

Copy-Item -Path "$PSScriptRoot\*" -Destination "E:\Games\Kerbal Space Program\Ships\Script" -Include "*.ks" -Recurse
Copy-Item -Path "$PSScriptRoot\*" -Destination "E:\Games\Kerbal Space Program RSS\Ships\Script" -Include "*.ks" -Exclude $stockOnly -Recurse

Write-Host $(Get-Date -DisplayHint Time)