$scriptsDirectory = "E:\Games\Kerbal Space Program RSS\Ships\Script"
Copy-Item -Path "$PSScriptRoot\*" -Destination $scriptsDirectory -Include "*.ks"  -Recurse
Write-Host $(Get-Date -DisplayHint Time)