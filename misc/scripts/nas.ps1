### Instructions
# This script is to use a NAS to store your ROMs and save files
# Change the path on $nasPath variable or, create a folder structure as found on .emulationstation folder (for root and roms folder)
# The structure for save files are different on purpose, but you can change that as well
# Execute this script after prepare.ps1

# Get paths
$retroarchConfigPath = $env:userprofile + "\.emulationstation\systems\retroarch\retroarch.cfg"
$nasPath = "V:\"

Write-Host "RetroArch filepath: $retroarchConfigPath"
Write-Host "NAS share path $nasPath"

# Console saves - retroarch.cfg
$settingToFind = 'savefile_directory = ":\saves"'
$settingToSet = 'savefile_directory = "' + $nasPath + 'savegames"'
(Get-Content $retroarchConfigPath) -replace [regex]::escape($settingToFind), $settingToSet | Set-Content $retroarchConfigPath

# Save states - retroarch.cfg
$settingToFind = 'savestate_directory = ":\states"'
$settingToSet = 'savestate_directory = "' + $nasPath + 'savegames\states"'
(Get-Content $retroarchConfigPath) -replace [regex]::escape($settingToFind), $settingToSet | Set-Content $retroarchConfigPath


# roms folder - es_systems.cfg
$esConfigFile = $env:userprofile + "\.emulationstation\es_systems.cfg"

Write-Host "systems path: $esConfigFile"

$settingToFind = "<path>" + $env:userprofile + "\.emulationstation\"
$settingToSet = "<path>" + $nasPath
(Get-Content $esConfigFile) -replace [regex]::escape($settingToFind), $settingToSet | Set-Content $esConfigFile

Write-Host "Successfully altered Paths for NAS"
