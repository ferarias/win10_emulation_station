#Require -Version 5.0
using namespace System.IO

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $InstallDir,

    [Parameter()]
    [String]
    $CustomRomsFolder
)

. .\functions.ps1

# #############################################################################
# Setup some basic directories and stuff
Write-Host "Running from $PSScriptRoot"
New-Item -ItemType Directory -Force -Path $InstallDir
Write-Host "INFO: Install directory is $InstallDir"
$ESRootFolder = [Path]::Combine($InstallDir, "EmulationStation");
Write-Host "INFO: EmulationStation root directory is $ESRootFolder"
$ESDataFolder = [Path]::Combine($ESRootFolder, ".emulationstation")
Write-Host "INFO: EmulationStation data directory is $ESDataFolder"

# ROMs folder
if([String]::IsNullOrEmpty($CustomRomsFolder)) {
    $RomsFolder = [Path]::Combine($ESDataFolder, "roms")
    New-Item -ItemType Directory -Force -Path $RomsFolder | Out-Null
} else {
    if(-Not (Test-Path -Path $CustomRomsFolder)) {
        Write-Information "Custom ROMs folder $CustomRomsFolder does not exist. Creating it."
        New-Item -ItemType Directory -Force -Path $CustomRomsFolder
    }
    $RomsFolder = $CustomRomsFolder
}
Write-Host "INFO: ROMs directory is $RomsFolder"

$ESSystemsPath = [Path]::Combine($ESDataFolder , "systems")
Write-Host "INFO: EmulationStation systems (emulators) directory is $ESSystemsPath"
$ESThemesPath = [Path]::Combine($ESDataFolder , "themes")
Write-Host "INFO: EmulationStation themes directory is $ESThemesPath"


# #############################################################################
# Acquire required files and leave them in a folder for later use
$downloadsFolder = [Path]::Combine("$PSScriptRoot", "downloads")
Write-Host "INFO: Downloads directory is: $downloadsFolder"

$requirementsFolder = [Path]::Combine("$PSScriptRoot", "requirements")
Write-Host "INFO: Requirements directory is: $requirementsFolder"
New-Item -ItemType Directory -Force -Path $requirementsFolder

# Acquire some basic software required
Get-ChildItem $downloadsFolder -Filter "*-downloads.json" | ForEach-Object {
    Write-Host "INFO: Downloading core software from: $_"
    Get-RemoteFiles $_.FullName $requirementsFolder
}

# Acquire github releases
Get-ChildItem $downloadsFolder -Filter "*-releases.json" | ForEach-Object {
    Write-Host "INFO: Downloading releases in GitHub from: $_"
    Get-Releases $_.FullName $requirementsFolder
}

# Acquire freeware games
Get-ChildItem $downloadsFolder -Filter "*-games.json" | ForEach-Object {
    Write-Host "INFO: Downloading freeware ROMs from: $_"
    Get-RemoteFiles $_.FullName $requirementsFolder
}

# #############################################################################
# Prepare 7-zip
if (!(Get-MyModule -name "7Zip4Powershell")) { 
    Write-Host "INFO: Installing required 7zip module in Powershell"
    Install-Module -Name "7Zip4Powershell" -Scope CurrentUser -Force 
}
Expand-7Zip -ArchiveFileName "$requirementsFolder\7z1900.exe" -TargetPath "$requirementsFolder\7z\"

# #############################################################################
# Install Emulation Station
Expand-PackedFile "$requirementsFolder/emulationstation_win32_latest.zip" $ESRootFolder
Expand-PackedFile "$requirementsFolder/EmulationStation-Win32-continuous-master.zip" $ESRootFolder 

# #############################################################################
# Install Retroarch
$retroArchTempPath = "$requirementsFolder\retroarch"
$retroArchPath = "$ESSystemsPath\retroarch\"
Write-Host "INFO: Setting up RetroArch in $retroArchPath..."
if (!(Test-Path $retroArchTempPath)) {
    $retroArchPackage = [Path]::Combine($requirementsFolder, "RetroArch.7z");
    if (Test-Path $retroArchPackage) {
        Write-Host "INFO: Extracting RetroArch..."
        Extract -Path $retroArchPackage -Destination $retroArchTempPath | Out-Null
    }
    else {
        Write-Host "ERROR: $retroArchBinary not found."
        exit -1
    }
}
Write-Host "INFO: Copying RetroArch files. This may take a while, so be patient..."
Robocopy.exe $retroArchTempPath $retroArchPath /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

# Install Retroarch cores
$coresPath = [Path]::Combine($retroArchPath, "cores");
$coresFile = [Path]::Combine($downloadsFolder, "lr-cores-downloads.json");

Get-Content $coresFile | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object {
    $coreZip = [Path]::Combine($requirementsFolder, $_.file)
    if (Test-Path $coreZip) {
        Extract -Path $coreZip -Destination $coresPath | Out-Null
    }
    else {
        Write-Host "ERROR: $coreZip not found."
    }
}

# #############################################################################
# Setup other systems
# PSX Setup
Expand-PackedFile "$requirementsFolder/ePSXe205.zip" "$ESSystemsPath/epsxe"

# CEMU Setup
Expand-PackedFile "$requirementsFolder/cemu_1.22.0.zip" "$ESSystemsPath/cemu" "cemu_1.22.0"

# PS2 Setup
Expand-PackedFile "$requirementsFolder/pcsx2-1.6.0-setup.exe" "$ESSystemsPath/pcsx2" "`$TEMP/PCSX2 1.6.0"

# Dolphin Setup
Expand-PackedFile "$requirementsFolder/dolphin-master-5.0-12716-x64.7z" "$ESSystemsPath/dolphin" "Dolphin-x64"
$dolphinBinary = "$ESSystemsPath/dolphin/Dolphin.exe"
Write-Host "INFO: Generating Dolphin Config"
New-Item -Path "$ESSystemsPath/dolphin/portable.txt" -ItemType File -Force | Out-Null
New-Item -Path "$ESSystemsPath/dolphin/User/Config" -ItemType Directory -Force | Out-Null
$dolphinConfigFile = "$ESSystemsPath/dolphin/User/Config/Dolphin.ini"
$newDolphinConfigFile = [Path]::Combine($PSScriptRoot, "configs", "Dolphin.ini")
Copy-Item -Path $newDolphinConfigFile -Destination $dolphinConfigFile -Force
(Get-Content $dolphinConfigFile) -replace "{ESSystemsPath}", $ESSystemsPath | Set-Content $dolphinConfigFile

# Start Retroarch and generate a config.
$retroarchExecutable = "$retroArchPath\retroarch.exe"
$retroarchConfigPath = "$retroArchPath\retroarch.cfg"

if (Test-Path $retroarchExecutable) {
    
    Write-Host "INFO: Retroarch executable found, launching"
    Start-Process $retroarchExecutable
    
    while (!(Test-Path $retroarchConfigPath)) { 
        Write-Host "INFO: Checking for retroarch config file $retroarchConfigPath"
        Start-Sleep 5
    }

    $retroarchProcess = Get-Process retroarch.exe -ErrorAction SilentlyContinue
    if ($retroarchProcess) {
        $retroarchProcess.CloseMainWindow()
        Start-sleep 5
        if (!$retroarchProcess.HasExited) {
            $retroarchProcess | Stop-Process -Force
        }
    }
    Stop-Process -Name "retroarch" -ErrorAction SilentlyContinue

}
else {
    Write-Host "ERROR: Could not find $retroarchExecutable"
    exit -1
}

# Tweak retroarch config!
Write-Host "INFO: Replacing RetroArch config"
$settingToFind = 'video_fullscreen = "false"'
$settingToSet = 'video_fullscreen = "true"'
(Get-Content $retroarchConfigPath) -replace $settingToFind, $settingToSet | Set-Content $retroarchConfigPath

$settingToFind = 'savestate_auto_load = "false"'
$settingToSet = 'savestate_auto_load = "true"'
(Get-Content $retroarchConfigPath) -replace $settingToFind, $settingToSet | Set-Content $retroarchConfigPath

$settingToFind = 'input_player1_analog_dpad_mode = "0"'
$settingToSet = 'input_player1_analog_dpad_mode = "1"'
(Get-Content $retroarchConfigPath) -replace $settingToFind, $settingToSet | Set-Content $retroarchConfigPath

$settingToFind = 'input_player2_analog_dpad_mode = "0"'
$settingToSet = 'input_player2_analog_dpad_mode = "1"'
(Get-Content $retroarchConfigPath) -replace $settingToFind, $settingToSet | Set-Content $retroarchConfigPath

# #############################################################################
# Set EmulationStation configurations
$ESSettingsFile = "$ESDataFolder\es_settings.cfg"
Write-Host "INFO: Generating ES settings file at $ESSettingsFile"
$newEsConfigFile = [Path]::Combine($PSScriptRoot, "configs", "es_settings.cfg")
Copy-Item -Path $newEsConfigFile -Destination $ESSettingsFile -Force
(Get-Content $ESSettingsFile) -replace "{ESInstallFolder}", $ESRootFolder | Set-Content $ESSettingsFile

# Set a default keyboard mapping for EmulationStation
$esInputConfigFile = "$ESDataFolder\es_input.cfg"
Write-Host "INFO: Setting up Emulation Station basic keyboard input at $esInputConfigFile"
$newEsInputConfigFile = [Path]::Combine($PSScriptRoot, "configs", "es_input.cfg")
Copy-Item -Path $newEsInputConfigFile -Destination $esInputConfigFile

# Setup EmulationStation available systems
$ESSystemsConfigPath = "$ESDataFolder/es_systems.cfg"
Write-Host "INFO: Setting up EmulationStation Systems Config at $ESSystemsConfigPath"
$systems = @{
    "nes"          = @("Nintendo Entertainment System", ".nes .NES", "$retroarchExecutable -L $coresPath\fceumm_libretro.dll %ROM%", "nes", "nes");
    "snes"         = @("Super Nintendo", ".smc .sfc .fig .swc .SMC .SFC .FIG .SWC", "$retroarchExecutable -L $coresPath\snes9x_libretro.dll %ROM%", "snes", "snes");
    "n64"          = @("Nintendo 64", ".z64 .Z64 .n64 .N64 .v64 .V64", "$retroarchExecutable -L $coresPath\parallel_n64_libretro.dll %ROM%", "n64", "n64");
    "gc"           = @("Gamecube", ".iso .ISO", "$dolphinBinary -e `"%ROM_RAW%`"", "gc", "gc");
    "wii"          = @("Nintendo Wii", ".iso .ISO .wad .WAD", "$dolphinBinary -e `"%ROM_RAW%`"", "wii", "wii");
    "gb"           = @("Game Boy", ".gb .zip .ZIP .7z", "$retroarchExecutable -L $coresPath\gambatte_libretro.dll %ROM%", "gb", "gb");
    "gbc"          = @("Game Boy Color", ".gbc .GBC .zip .ZIP", "$retroarchExecutable -L $coresPath\gambatte_libretro.dll %ROM%", "gbc", "gbc");
    "gba"          = @("Game Boy Advance", ".gba .GBA", "$retroarchExecutable -L $coresPath\vba_next_libretro.dll %ROM%", "gba", "gba");
    "psx"          = @("Playstation", ".cue .iso .pbp .CUE .ISO .PBP", "${psxEmulatorPath}ePSXe.exe -bios ${psxBiosPath}SCPH1001.BIN -nogui -loadbin %ROM%", "psx", "psx");
    "ps2"          = @("Playstation 2", ".iso .img .bin .mdf .z .z2 .bz2 .dump .cso .ima .gz", "${ps2Binary} %ROM% --fullscreen --nogui", "ps2", "ps2");
    "mame"         = @("MAME", ".zip .ZIP", "$retroarchExecutable -L $coresPath\hbmame_libretro.dll %ROM%", "mame", "mame");
    "fba"          = @("Final Burn Alpha", ".zip .ZIP .fba .FBA", "$retroarchExecutable -L $coresPath\fbalpha2012_libretro.dll %ROM%", "arcade", "");
    "amiga"        = @("Amiga", ".adf .ADF", "$retroarchExecutable -L $coresPath\puae_libretro.dll %ROM%", "amiga", "amiga");
    "atari2600"    = @("Atari 2600", ".a26 .bin .rom .A26 .BIN .ROM", "$retroarchExecutable -L $coresPath\stella_libretro.dll %ROM%", "atari2600", "atari2600");
    "atari7800"    = @("Atari 7800 Prosystem", ".a78 .bin .A78 .BIN", "$retroarchExecutable -L $coresPath\prosystem_libretro.dll %ROM%", "atari7800", "atari7800");
    "c64"          = @("Commodore 64", ".crt .d64 .g64 .t64 .tap .x64 .zip .CRT .D64 .G64 .T64 .TAP .X64 .ZIP", "$retroarchExecutable -L $coresPath\vice_x64_libretro.dll %ROM%", "c64", "c64");
    "megadrive"    = @("Sega Mega Drive / Genesis", ".smd .SMD .bin .BIN .gen .GEN .md .MD .zip .ZIP", "$retroarchExecutable -L $coresPath\genesis_plus_gx_libretro.dll %ROM%", "genesis,megadrive", "megadrive");
    "mastersystem" = @("Sega Master System", ".bin .sms .zip .BIN .SMS .ZIP", "$retroarchExecutable -L $coresPath\genesis_plus_gx_libretro.dll %ROM%", "mastersystem", "mastersystem");
    "msx"          = @("MSX", ".col .dsk .mx1 .mx2 .rom .COL .DSK .MX1 .MX2 .ROM", "$retroarchExecutable -L $coresPath\fmsx_libretro.dll %ROM%", "msx", "msx");
    "neogeo"       = @("Neo Geo", ".zip .ZIP", "$retroarchExecutable -L $coresPath\fbalpha2012_libretro.dll %ROM%", "neogeo", "neogeo");
    "ngp"          = @("Neo Geo Pocket", ".ngp .ngc .zip .ZIP", "$retroarchExecutable -L $coresPath\race_libretro.dll %ROM%", "ngp", "ngp");
    "scummvm"      = @("ScummVM", ".bat .BAT", "%ROM%", "pc", "scummvm");
    "wiiu"         = @("Nintendo Wii U", ".rpx .RPX", "START /D $cemuBinary -f -g `"%ROM_RAW%`"", "wiiu", "wiiu");
}
Write-ESSystemsConfig $ESSystemsConfigPath $systems $RomsFolder

# Setup EmulationStation theme
Write-Host "INFO: Setting up Emulation Station theme recalbox-backport"
$themeFile = "$requirementsFolder\recalbox-backport-v2-recalbox-backport-v2.1.zip"
$themePath = "$ESThemesPath\recalbox-backport\"
if (Test-Path $themeFile) {
    Extract -Path $themeFile -Destination $requirementsFolder | Out-Null
    $themesFolder = "$requirementsFolder\recalbox-backport\"
    robocopy $themesFolder $themePath /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
}
else {
    Write-Host "ERROR: $themeFile not found."
    exit -1
}

# #############################################################################
# Path creation + Open-Source / Freeware Rom population
Write-Host "INFO: Creating ROM directories and filling with freeware ROMs $path"
Get-Content $freeGamesFile | ConvertFrom-Json | Select-Object -ExpandProperty games | ForEach-Object {
    if([String]::IsNullOrEmpty( $_.file ) ) {
        continue;
    }
    $sourceFile = [Path]::Combine($requirementsFolder, $_.file)
    $targetFolder = [Path]::Combine($RomsFolder, $_.platform)

    if (Test-Path $sourceFile) {
        if ( $sourceFile.EndsWith("zip") -or $sourceFile.EndsWith("7z") -or $sourceFile.EndsWith("gz") ) {
            Expand-PackedFile $sourceFile $targetFolder
        }
        else {
            Move-Item -Path $sourceFile -Destination $targetFolder -Force | Out-Null
        }
    }
    else {
        Write-Host "Warning: $sourceFile not found."
    }
}

# TODO: find/test freeware games for these emulators.
Write-Host "INFO: Creating empty ROM directories $path"
New-Item -ItemType Directory -Force -Path "$RomsFolder\gb" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\fba" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\mame" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\wiiu" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\neogeo" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\msx" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\c64" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\amiga" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\atari7800" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\gc" | Out-Null
# TODO: write a bat to boot some DOS/Scumm games
New-Item -ItemType Directory -Force -Path "$RomsFolder\scummvm"


# Add an scraper to ROMs folder
Write-Host "INFO: Adding scraper in $RomsFolder"
$scraperZip = "$requirementsFolder\scraper_windows_amd64*.zip"
if (Test-Path $scraperZip) {
    Extract -Path $scraperZip -Destination $RomsFolder | Out-Null
}
else {
    Write-Host "ERROR: $scraperZip not found."
    exit -1
}

# Create Shortcuts
Write-Host "INFO: Creating shortcuts"
$ESBatName = "launch_portable.bat"
$ESBatWindowed = "launch_portable_windowed.bat"
$ESIconPath = [Path]::Combine($ESRootFolder, "icon.ico")
$ESPortableBat = [Path]::Combine($ESRootFolder, $ESBatName)
$ESPortableWindowedBat = [Path]::Combine($ESRootFolder, $ESBatWindowed)
if (!(Test-Path $ESPortableBat)) {
    $batContents = "set HOME=%~dp0
    emulationstation.exe"
    New-Item -Path $ESRootFolder -Name $ESBatName -ItemType File -Value $batContents | Out-Null
}
if (!(Test-Path $ESPortableWindowedBat)) {
    $batContents = "set HOME=%~dp0
    emulationstation.exe --resolution 960 720 --windowed"
    New-Item -Path $ESRootFolder -Name $ESBatWindowed -ItemType File -Value $batContents | Out-Null
}

Add-Shortcut -ShortcutLocation "$InstallDir\Roms.lnk" -ShortcutTarget $RomsFolder
Add-Shortcut -ShortcutLocation "$InstallDir\Cores.lnk" -ShortcutTarget "$ESDataFolder\systems\retroarch\cores"
Add-Shortcut -ShortcutLocation "$InstallDir\EmulationStation.lnk" -ShortcutTarget $ESPortableBat -ShortcutIcon $ESIconPath -WorkingDir $ESRootFolder
Add-Shortcut -ShortcutLocation "$InstallDir\EmulationStation (Windowed).lnk" -ShortcutTarget $ESPortableWindowedBat -ShortcutIcon $ESIconPath -WorkingDir $ESRootFolder
$desktop = [System.Environment]::GetFolderPath('Desktop')
Add-Shortcut -ShortcutLocation "$desktop\EmulationStation.lnk" -ShortcutTarget $ESPortableBat -ShortcutIcon $ESIconPath -WorkingDir $ESRootFolder
Add-Shortcut -ShortcutLocation "$desktop\EmulationStation (Windowed).lnk" -ShortcutTarget $ESPortableWindowedBat -ShortcutIcon $ESIconPath -WorkingDir $ESRootFolder

Write-Host "INFO: Setup completed"