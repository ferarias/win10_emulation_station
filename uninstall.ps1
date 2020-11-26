function RemoveIfExists {
    param ([String]$file)

    if(Test-Path $file) {
        Remove-Item -Path $file
    }
}


$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptPath
Write-Host "INFO: Script directory is: $scriptDir"

$installDir = "D:\Emu2"
Write-Host "INFO: Install directory is: $installDir"


Write-Host "INFO: Removing desktop shortcuts"
$desktop = [System.Environment]::GetFolderPath('Desktop')
RemoveIfExists "$desktop\Windowed EmulationStation.lnk"
RemoveIfExists "$desktop\EmulationStation.lnk"
RemoveIfExists "$desktop\Cores Location.lnk"
RemoveIfExists "$desktop\Roms Location.lnk"

$esUserFolder = "$env:userprofile\.emulationstation"
Write-Host "INFO: Removing Emulation Station user folder: $esUserFolder"
if(Test-Path $esUserFolder) {
    Remove-Item -Recurse -Force -Path $esUserFolder
}

$requirementsFolder = "$PSScriptRoot\requirements"

$recalboxThemeFolder = "$requirementsFolder\recalbox-backport"
if(Test-Path $recalboxThemeFolder) {
    Write-Host "INFO: Removing RecalBox theme folder: $recalboxThemeFolder"
    Remove-Item -Recurse -Force -Path $recalboxThemeFolder
}

# Write-Host "INFO: Removing Requirements folder: $requirementsFolder"
# if(Test-Path $requirementsFolder) {
#     Remove-Item -Recurse -Force -Path $requirementsFolder
# }

if(Test-Path $installDir) {
    Write-Host "INFO: Removing install folder: $installDir"
    Remove-Item -Recurse -Force -Path $installDir
}


Write-Host "INFO: Uninstall completed"