function RemoveIfExists {
    param ([String]$file)

    if(Test-Path $file) {
        Remove-Item -Path $file
    }
}


Set-ExecutionPolicy Bypass -Scope Process -Force

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptPath
Write-Host "INFO: Script directory is: $scriptDir"

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
Write-Host "INFO: Removing Requirements folder: $requirementsFolder"
if(Test-Path $requirementsFolder) {
    Remove-Item -Recurse -Force -Path $requirementsFolder
}

Write-Host "INFO: Uninstall completed"