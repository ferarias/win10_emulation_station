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

. (Join-Path $PSScriptRoot functions.ps1)

# TODO SAVEGAMES

Write-Host -ForegroundColor Magenta "***************************************"
Write-Host -ForegroundColor White   "WINDOWS 10 EMULATION STATION EASY SETUP"
Write-Host -ForegroundColor Magenta "***************************************"
try {
    # #############################################################################
    # SETUP BASIC STUFF
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "SETTING UP REQUIRED PATHS"
    # Setup some basic directories and stuff
    Write-Host "INFO: Running from $PSScriptRoot"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Write-Host "INFO: Install directory is $InstallDir"
    $ESRootFolder = [Path]::Combine($InstallDir, "EmulationStation");
    Write-Host "INFO: EmulationStation root directory is $ESRootFolder"
    $ESDataFolder = [Path]::Combine($ESRootFolder, ".emulationstation")
    Write-Host "INFO: EmulationStation data directory is $ESDataFolder"

    # Determine the ROMs directory
    if ([String]::IsNullOrEmpty($CustomRomsFolder)) {
        $RomsFolder = [Path]::Combine($ESDataFolder, "roms")
        New-Item -ItemType Directory -Force -Path $RomsFolder | Out-Null
    }
    else {
        if (-Not (Test-Path -Path $CustomRomsFolder)) {
            Write-Host "INFO: Custom ROMs folder $CustomRomsFolder does not exist. Creating it."
            New-Item -ItemType Directory -Force -Path $CustomRomsFolder | Out-Null
        }
        $RomsFolder = $CustomRomsFolder
    }
    Write-Host "INFO: ROMs directory is $RomsFolder"

    # Set the files that will be downloaded in each section
    # You can take a look at the "downloads" folder to see which downloads are configured
    $downloadsFolder = [Path]::Combine("$PSScriptRoot", "downloads")
    Write-Host "INFO: Downloads directory is: $downloadsFolder."
    $downloads = @{ 
        Core    = [Path]::Combine($downloadsFolder, "core.json") ; 
        Systems = [Path]::Combine($downloadsFolder, "systems.json") ; 
        Lrcores = [Path]::Combine($downloadsFolder, "lr-cores.json") ; 
        Misc    = [Path]::Combine($downloadsFolder, "misc.json") ;
        Games   = [Path]::Combine($downloadsFolder, "games")
    }

    # #############################################################################
    # ## CORE SOFTWARE
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "INSTALLING CORE SOFTWARE"
    Write-Host -ForegroundColor DarkGreen "Downloading core software from $($downloads.Core)"
    Get-RemoteFiles $downloads.Core $cacheFolder

    # Emulation Station
    Expand-PackedFile "$cacheFolder/emulationstation_win32_latest.zip" $ESRootFolder
    Expand-PackedFile "$cacheFolder/EmulationStation-Win32.zip" $ESRootFolder 

    # #############################################################################
    # ## SYSTEMS
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "INSTALLING SYSTEMS (EMULATORS)"
    $ESSystemsPath = [Path]::Combine($ESDataFolder, "systems")
    Write-Host "INFO: EmulationStation systems (emulators) directory is $ESSystemsPath"

    Write-Host -ForegroundColor DarkGreen "Downloading Systems software from $($downloads.Systems) to $cacheFolder"
    Get-RemoteFiles $downloads.Systems $cacheFolder

    Get-Content $downloads.Systems | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object {
        $file = [Path]::Combine($cacheFolder, $_.file)
        $installPath = [Path]::Combine($ESSystemsPath, $_.folder)
        $innerFolder = $_.innerFolder
        Write-Host -ForegroundColor Cyan "Installing $file system in $installPath"
        Expand-PackedFile $file $installPath $innerFolder | Out-Null
    }

    # #############################################################################
    # ## SYSTEMS CONFIGURATION
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "CONFIGURING SYSTEMS"
    $configsPath = Join-Path -Path $PSScriptRoot -ChildPath "configs"
    # RETROARCH system configuration
    $retroArchInstallPath = [Path]::Combine($ESSystemsPath, "retroarch")
    $retroarchExecutable = [Path]::Combine($retroArchInstallPath, "retroarch.exe")
    $retroarchConfigPath = [Path]::Combine($retroArchInstallPath, "retroarch.cfg")

    # Installing libretro cores
    Write-Host -ForegroundColor DarkGreen "Downloading libretro cores from: $($downloads.Lrcores)"
    Get-RemoteFiles $downloads.Lrcores $cacheFolder
    $retroArchCoresFile = [Path]::Combine($downloadsFolder, "lr-cores.json");
    $retroArchCoresPath = [Path]::Combine($retroArchInstallPath, "cores");

    Get-Content $retroArchCoresFile | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object {
        $coreZip = [Path]::Combine($cacheFolder, $_.file)
        Expand-PackedFile $coreZip $retroArchCoresPath | Out-Null
    }

    # Start Retroarch and generate a config.
    if (Test-Path $retroarchExecutable) {
    
        Write-Host "Retroarch executable found, launching"
        Start-Process $retroarchExecutable
    
        while (!(Test-Path $retroarchConfigPath)) { 
            Write-Host "Checking for retroarch config file $retroarchConfigPath"
            Start-Sleep 5
        }

        $retroarchProcess = Get-Process -Name "*retroarch*" -Verbose
        if ($retroarchProcess) {
            $retroarchProcess.CloseMainWindow()
            Start-sleep 5
            if (!$retroarchProcess.HasExited) {
                $retroarchProcess | Stop-Process -Force
            }
        }

    }
    else {
        Write-Host -ForegroundColor Red "ERROR: Could not find $retroarchExecutable"
        exit -1
    }

    # Tweak retroarch config!
    Write-Host -ForegroundColor Cyan "Replacing RetroArch config"
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

    # DOLPHIN system configuration
    $dolphinBinary = "$ESSystemsPath/dolphin/Dolphin.exe"
    Write-Host -ForegroundColor Cyan "Generating Dolphin Config"
    New-Item -Path "$ESSystemsPath/dolphin/portable.txt" -ItemType File -Force | Out-Null
    New-Item -Path "$ESSystemsPath/dolphin/User/Config" -ItemType Directory -Force | Out-Null
    $dolphinConfigFile = "$ESSystemsPath/dolphin/User/Config/Dolphin.ini"
    $newDolphinConfigFile = [Path]::Combine($configsPath, "Dolphin.ini")
    Copy-Item -Path $newDolphinConfigFile -Destination $dolphinConfigFile -Force
    (Get-Content $dolphinConfigFile) -replace "{ESSystemsPath}", $ESSystemsPath | Set-Content $dolphinConfigFile

    # AMIGA system configuration
    $winuaePath = Join-Path -Path $ESSystemsPath -ChildPath "winuae" -Resolve
    Write-Host -ForegroundColor Cyan "Generating WinUAE Config"
    $newWinUaeIniFile = [Path]::Combine($configsPath, "winuae.ini")
    $winUaeIniFile = Join-Path -Path $winuaePath -ChildPath "winuae.ini"
    Copy-Item -Path $newWinUaeIniFile -Destination $winUaeIniFile -Force
    New-Item -Path "$ESSystemsPath/winuae/conf" -ItemType Directory -Force | Out-Null
    New-Item -Path "$ESSystemsPath/winuae/rom" -ItemType Directory -Force | Out-Null
    New-Item -Path "$ESSystemsPath/winuae/disk" -ItemType Directory -Force | Out-Null
    New-Item -Path "$ESSystemsPath/winuae/floppy" -ItemType Directory -Force | Out-Null
    New-Item -Path "$ESSystemsPath/winuae/media" -ItemType Directory -Force | Out-Null
    Get-ChildItem -Path $configsPath -Filter *.uae | ForEach-Object { 
        Copy-Item -Path $_ -Destination "$ESSystemsPath/winuae/conf/$($_.Name)" -Force | Out-Null
    }

    # Create a launcher bat
    $batContents = "@SET ECHO OFF
IF ""%1""=="""" GOTO fin
IF /I ""%~x1""=="".lha"" (
    CD $winuaePath
    .\winuae64.exe -f .\conf\a1200.uae -s ""filesystem2=rw,DH0:WHDLoad-Game-Launcher:.\disk\WHDLoad-Game-Launcher,0"" -s ""filesystem2=ro,DH1:%~nx1:%~1,-128"" -G
) ELSE (
    $retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %~1
)
:fin
"
    New-Item -Path "$ESSystemsPath/winuae" -Name "launcher.bat" -ItemType File -Value $batContents -Force | Out-Null
    
    $whdLauncher = Join-Path $winuaePath "launcher.bat"
    
    # EMULATION STATION CONFIGURATION
    # Set EmulationStation available systems (es_systems.cfg)
    $ESSystemsConfigPath = "$ESDataFolder/es_systems.cfg"
    Write-Host -ForegroundColor Cyan "Setting up EmulationStation Systems Config at $ESSystemsConfigPath"
    $systems = @{
        "amiga500"     = @("Commodore Amiga 500", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amiga500");
        "amigacdtv"    = @("Commodore Amiga CDTV", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amigacdtv");
        "amiga600"     = @("Commodore Amiga 600", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amiga600");    
        "amiga1200"    = @("Commodore Amiga 1200", ".adf .ADF .lha .LHA", "$whdLauncher %ROM%", "amiga", "amiga1200");
        "amigacd32"    = @("Commodore Amiga CD32", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amigacd32");
        "atari2600"    = @("Atari 2600", ".a26 .bin .rom .A26 .BIN .ROM", "$retroarchExecutable -L $retroArchCoresPath\stella_libretro.dll %ROM%", "atari2600", "atari2600");
        "atari7800"    = @("Atari 7800 Prosystem", ".a78 .bin .A78 .BIN", "$retroarchExecutable -L $retroArchCoresPath\prosystem_libretro.dll %ROM%", "atari7800", "atari7800");
        "c64"          = @("Commodore 64", ".crt .d64 .g64 .t64 .tap .x64 .zip .CRT .D64 .G64 .T64 .TAP .X64 .ZIP", "$retroarchExecutable -L $retroArchCoresPath\vice_x64_libretro.dll %ROM%", "c64", "c64");
        "fba"          = @("Final Burn Alpha", ".zip .ZIP .fba .FBA", "$retroarchExecutable -L $retroArchCoresPath\fbalpha2012_libretro.dll %ROM%", "arcade", "");
        "gb"           = @("Game Boy", ".gb .zip .ZIP .7z", "$retroarchExecutable -L $retroArchCoresPath\gambatte_libretro.dll %ROM%", "gb", "gb");
        "gba"          = @("Game Boy Advance", ".gba .GBA", "$retroarchExecutable -L $retroArchCoresPath\vba_next_libretro.dll %ROM%", "gba", "gba");
        "gbc"          = @("Game Boy Color", ".gbc .GBC .zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\gambatte_libretro.dll %ROM%", "gbc", "gbc");
        "gc"           = @("Gamecube", ".iso .ISO", "$dolphinBinary -e `"%ROM_RAW%`"", "gc", "gc");
        "mame"         = @("MAME", ".zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\hbmame_libretro.dll %ROM%", "mame", "mame");
        "mastersystem" = @("Sega Master System", ".bin .sms .zip .BIN .SMS .ZIP", "$retroarchExecutable -L $retroArchCoresPath\genesis_plus_gx_libretro.dll %ROM%", "mastersystem", "mastersystem");
        "megadrive"    = @("Sega Mega Drive / Genesis", ".smd .SMD .bin .BIN .gen .GEN .md .MD .zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\genesis_plus_gx_libretro.dll %ROM%", "genesis,megadrive", "megadrive");
        "msx"          = @("MSX", ".col .dsk .mx1 .mx2 .rom .COL .DSK .MX1 .MX2 .ROM", "$retroarchExecutable -L $retroArchCoresPath\fmsx_libretro.dll %ROM%", "msx", "msx");
        "n64"          = @("Nintendo 64", ".z64 .Z64 .n64 .N64 .v64 .V64", "$retroarchExecutable -L $retroArchCoresPath\parallel_n64_libretro.dll %ROM%", "n64", "n64");
        "neogeo"       = @("Neo Geo", ".zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\fbalpha2012_libretro.dll %ROM%", "neogeo", "neogeo");
        "nes"          = @("Nintendo Entertainment System", ".nes .NES", "$retroarchExecutable -L $retroArchCoresPath\fceumm_libretro.dll %ROM%", "nes", "nes");
        "ngp"          = @("Neo Geo Pocket", ".ngp .ngc .zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\race_libretro.dll %ROM%", "ngp", "ngp");
        "ps2"          = @("Playstation 2", ".iso .img .bin .mdf .z .z2 .bz2 .dump .cso .ima .gz", "${ps2Binary} %ROM% --fullscreen --nogui", "ps2", "ps2");
        "psx"          = @("Playstation", ".cue .iso .pbp .CUE .ISO .PBP", "${psxEmulatorPath}ePSXe.exe -bios ${psxBiosPath}SCPH1001.BIN -nogui -loadbin %ROM%", "psx", "psx");
        "scummvm"      = @("ScummVM", ".bat .BAT", "%ROM%", "pc", "scummvm");
        "snes"         = @("Super Nintendo", ".smc .sfc .fig .swc .SMC .SFC .FIG .SWC", "$retroarchExecutable -L $retroArchCoresPath\snes9x_libretro.dll %ROM%", "snes", "snes");
        "wii"          = @("Nintendo Wii", ".iso .ISO .wad .WAD", "$dolphinBinary -e `"%ROM_RAW%`"", "wii", "wii");
        "wiiu"         = @("Nintendo Wii U", ".rpx .RPX", "START /D $cemuBinary -f -g `"%ROM_RAW%`"", "wiiu", "wiiu");
    }
    Write-ESSystemsConfig $ESSystemsConfigPath $systems $RomsFolder

    # Set EmulationStation configurations (es_settings.cfg)
    $ESSettingsFile = "$ESDataFolder\es_settings.cfg"
    Write-Host -ForegroundColor Cyan "Generating ES settings file at $ESSettingsFile"
    $newEsConfigFile = [Path]::Combine($PSScriptRoot, "configs", "es_settings.cfg")
    Copy-Item -Path $newEsConfigFile -Destination $ESSettingsFile -Force
    (Get-Content $ESSettingsFile) -replace "{ESInstallFolder}", $ESRootFolder | Set-Content $ESSettingsFile

    # Set EmulationStation default keyboard mapping (es_input.cfg)
    $esInputConfigFile = "$ESDataFolder\es_input.cfg"
    Write-Host -ForegroundColor Cyan "Setting up Emulation Station basic keyboard input at $esInputConfigFile"
    $newEsInputConfigFile = [Path]::Combine($PSScriptRoot, "configs", "es_input.cfg")
    Copy-Item -Path $newEsInputConfigFile -Destination $esInputConfigFile


    & (Join-Path $PSScriptRoot updateGames.ps1) -gamesDownloads $downloads.Games -gameCacheFolder $(Join-Path -Path $cacheFolder  -ChildPath "games") -RomsFolder $RomsFolder

    # #############################################################################
    # MISC ADDITIONAL SOFTWARE
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "INSTALLING ADDITIONAL MISC SOFTWARE"
    Write-Host -ForegroundColor DarkGreen "Downloading misc additional packages from: $($downloads.Misc)"
    Get-RemoteFiles $downloads.Misc $cacheFolder

    $ESThemesPath = [Path]::Combine($ESDataFolder , "themes")
    Write-Host "INFO: EmulationStation themes directory is $ESThemesPath"

    # Setup EmulationStation theme
    Write-Host -ForegroundColor Cyan "Installing Emulation Station theme recalbox-backport"
    $themeFile = "$cacheFolder\recalbox-backport.zip"
    if (Test-Path $themeFile) {
        Expand-PackedFile $themeFile $ESThemesPath | Out-Null
    }
    else {
        Write-Host -ForegroundColor Red "ERROR: $themeFile not found."
        exit -1
    }

    # Add an scraper to ROMs folder
    Write-Host -ForegroundColor Cyan "Installing scraper in $RomsFolder"
    $scraperZip = "$cacheFolder\scraper_windows_amd64.zip"
    if (Test-Path $scraperZip) {
        Expand-PackedFile $scraperZip $RomsFolder | Out-Null
    }
    else {
        Write-Host "ERROR: $scraperZip not found."
        exit -1
    }

    # #############################################################################
    # CREATING SHORTCUTS
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "CREATING SHORTCUTS"
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

    Write-Host -ForegroundColor DarkYellow "FINISHED SETUP!"
}
catch { 
    Write-Error $_ 
}