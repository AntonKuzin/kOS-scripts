$targetDirectories = @(
    "E:\Games\Kerbal Space Program\Ships\Script",
    "E:\Games\Kerbal Space Program RSS\Ships\Script"
)

foreach ($dir in $targetDirectories)
{
    Copy-Item -Path "$PSScriptRoot\*" -Destination $dir -Include "*.ks"  -Recurse
}

Write-Host $(Get-Date -DisplayHint Time)