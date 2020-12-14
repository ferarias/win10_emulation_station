#Require -Version 5.0
using namespace System.IO

param (
    [Parameter(Mandatory)]$InstallDir,
    [String] $CustomRomsFolder
)

. .\functions.ps1

# #############################################################################
# Setup some basic directories and stuff
New-Item -ItemType Directory -Force -Path $InstallDir
Write-Host "INFO: Install directory is $InstallDir"
$ESRootFolder = [Path]::Combine($InstallDir, "EmulationStation");
Write-Host "INFO: EmulationStation root directory is $ESRootFolder"
$ESDataFolder = [Path]::Combine($ESRootFolder, ".emulationstation")
Write-Host "INFO: EmulationStation data directory is $ESDataFolder"

# ROMs folder
if([String]::IsNullOrEmpty($CustomRomsFolder)) {
    $RomsFolder = [Path]::Combine($ESDataFolder, "roms")
} else {
    if(-Not (Test-Path -Path $CustomRomsFolder)) {
        Write-Error "ERROR: Custom ROMs folder $CustomRomsFolder does not exist!"
        exit -1
    }
    $RomsFolder = $CustomRomsFolder
}
Write-Host "INFO: ROMs directory is $RomsFolder"

$ESSystemsPath = [Path]::Combine($ESDataFolder , "systems")
Write-Host "INFO: EmulationStation systems (emulators) directory is $ESSystemsPath"


# Setup requiremens folder
Write-Host "$PSScriptRoot"
$requirementsFolder = [Path]::Combine("$PSScriptRoot", "requirements")
Write-Host "INFO: Requirements directory is: $requirementsFolder"
New-Item -ItemType Directory -Force -Path $requirementsFolder

# Find downloads JSON file
$downloadsFile = [Path]::Combine("$PSScriptRoot", "download_list.json")
Write-Host "INFO: Downloads file is: $downloadsFile"


# Acquire files 
DownloadFiles $downloadsFile "core" $requirementsFolder
DownloadFiles $downloadsFile "lr-cores" $requirementsFolder
DownloadFiles $downloadsFile "freeware-games" $requirementsFolder
DownloadFiles $downloadsFile "misc" $requirementsFolder
GithubReleaseFiles $downloadsFile $requirementsFolder

# Prepare 7-zip
if (!(Get-MyModule -name "7Zip4Powershell")) { 
    Install-Module -Name "7Zip4Powershell" -Scope CurrentUser -Force 
}
Expand-7Zip -ArchiveFileName "$requirementsFolder\7z1900.exe" -TargetPath "$requirementsFolder\7z\"

# #############################################################################
# Install Emulation Station
SetupZip "$requirementsFolder/emulationstation_win32_latest.zip" "" $ESRootFolder
SetupZip "$requirementsFolder/EmulationStation-Win32-continuous-master.zip" "" $ESRootFolder 





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

# NES Setup
CopyCore $requirementsFolder "fceumm_libretro.dll.zip" $coresPath

# N64 Setup
CopyCore $requirementsFolder "parallel_n64_libretro.dll.zip" $coresPath

# FBA Setup
CopyCore $requirementsFolder "fbalpha2012_libretro.dll.zip" $coresPath

# GBA Setup
CopyCore $requirementsFolder "vba_next_libretro.dll.zip" $coresPath

# SNES Setup
CopyCore $requirementsFolder "snes9x_libretro.dll.zip" $coresPath

# Genesis GX Setup
CopyCore $requirementsFolder "genesis_plus_gx_libretro.dll.zip" $coresPath

# Game boy Colour Setup
CopyCore $requirementsFolder "gambatte_libretro.dll.zip" $coresPath

# Atari2600 Setup
CopyCore $requirementsFolder "stella_libretro.dll.zip" $coresPath

# MAME Setup
CopyCore $requirementsFolder "hbmame_libretro.dll.zip" $coresPath

# NeoGeo Pocket Setup
CopyCore $requirementsFolder "race_libretro.dll.zip" $coresPath

# MSX setup
CopyCore $requirementsFolder "fmsx_libretro.dll.zip" $coresPath

# C64 Setup
CopyCore $requirementsFolder "vice_x64_libretro.dll.zip" $coresPath

# Commodore Amiga Setup
CopyCore $requirementsFolder "puae_libretro.dll.zip" $coresPath

# PROSystem Setup
CopyCore $requirementsFolder "prosystem_libretro.dll.zip" $coresPath

# #############################################################################
# Setup other systems
# PSX Setup
SetupZip "$requirementsFolder/ePSXe205.zip" "" "$ESSystemsPath/epsxe"

# CEMU Setup
SetupZip "$requirementsFolder/cemu_1.22.0.zip" "cemu_1.22.0" "$ESSystemsPath/cemu"

# PS2 Setup
SetupZip "$requirementsFolder/pcsx2-1.6.0-setup.exe" "`$TEMP/PCSX2 1.6.0" "$ESSystemsPath/pcsx2"

# Dolphin Setup
SetupZip "$requirementsFolder/dolphin-master-5.0-12716-x64.7z" "Dolphin-x64" "$ESSystemsPath/dolphin"
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

# TODO: write a bat to boot some DOS/Scumm games
Add-Rom "" "$RomsFolder\scummvm"

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
$themesPath = "$ESDataFolder\themes\recalbox-backport\"
$themesFile = "$requirementsFolder\recalbox-backport-v2-recalbox-backport-v2.1.zip"
if (Test-Path $themesFile) {
    Extract -Path $themesFile -Destination $requirementsFolder | Out-Null
    $themesFolder = "$requirementsFolder\recalbox-backport\"
    robocopy $themesFolder $themesPath /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
}
else {
    Write-Host "ERROR: $themesFile not found."
    exit -1
}

# #############################################################################
# Add free roms
New-Item -ItemType Directory -Force -Path $RomsFolder | Out-Null

# Path creation + Open-Source / Freeware Rom population
Write-Host "INFO: Creating ROM directories and filling with freeware ROMs $path"
Add-Rom "$requirementsFolder\assimilate_full.zip" "$RomsFolder\nes"
Add-Rom "$requirementsFolder\pom-twin.zip" "$RomsFolder\n64"
Add-Rom "$requirementsFolder\uranus0ev_fix.gba" "$RomsFolder\gba"
Add-Rom "$requirementsFolder\T2002.gba" "$RomsFolder\gba"
Add-Rom "$requirementsFolder\rickdangerous.gen" "$RomsFolder\megadrive"
Add-Rom "$requirementsFolder\N-Warp Daisakusen V1.1.smc" "$RomsFolder\snes"
Add-Rom "$requirementsFolder\Marilyn_In_the_Magic_World_(010a).7z" "$RomsFolder\psx"
Add-Rom "$requirementsFolder\hermes-v.latest-ps2.zip" "$RomsFolder\ps2"
Add-Rom "$requirementsFolder\star_heritage.zip" "$RomsFolder\gbc"
Add-Rom "$requirementsFolder\WahMunchers-SMS-R2.zip" "$RomsFolder\mastersystem"
Add-Rom "$requirementsFolder\ramless_pong.bin" "$RomsFolder\atari2600"
Add-Rom "$requirementsFolder\neopocket.zip" "$RomsFolder\ngp"
Add-Rom "$requirementsFolder\Homebrew.Channel.-.OHBC.wad" "$RomsFolder\wii"

# TODO: find/test freeware games for these emulators.
Write-Host "INFO: Creating empty ROM directories $path"
Add-Rom "" "$RomsFolder\gb"
Add-Rom "" "$RomsFolder\fba"
Add-Rom "" "$RomsFolder\mame"
Add-Rom "" "$RomsFolder\wiiu"
Add-Rom "" "$RomsFolder\neogeo"
Add-Rom "" "$RomsFolder\msx"
Add-Rom "" "$RomsFolder\c64"
Add-Rom "" "$RomsFolder\amiga"
Add-Rom "" "$RomsFolder\atari7800"
Add-Rom "" "$RomsFolder\gc"


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