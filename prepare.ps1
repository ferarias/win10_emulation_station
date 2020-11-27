param (
    [Parameter(Mandatory)]
    $InstallDir,
    [bool] $Portable = $False
)

Function Get-MyModule {
    Param([string]$name)
    if (-not(Get-Module -name $name)) {
        if (Get-Module -ListAvailable |
            Where-Object { $_.name -eq $name }) {
            Import-Module -Name $name
            $true
        } #end if module available then import
        else { $false } #module not available
    } # end if not module
    else { $true } #module already loaded
} #end function get-MyModule

function DownloadFiles {
    param ([String]$jsonDownloadOption)
    
    Write-Host "Starting downloading of $jsonDownloadOption"

    Get-Content "$scriptDir\download_list.json" | ConvertFrom-Json | Select-Object -expand $jsonDownloadOption | ForEach-Object {
    
        $url = $_.url
        $file = $_.file
        $output = "$requirementsFolder\$file"

        if (![System.IO.File]::Exists($output)) {
    
            Write-Host "INFO: Downloading $file"
            Invoke-WebRequest $url -Out $output
            Write-Host "INFO: Finished Downloading $file successfully"
    
        }
        else {
    
            Write-Host $file "INFO: Already exists...Skipping download."
    
        }
    
    }

}

function GithubReleaseFiles {

    Get-Content "$scriptDir\download_list.json" | ConvertFrom-Json | Select-Object -expand releases | ForEach-Object {

        $repo = $_.repo
        $file = $_.file
        $releases = "https://api.github.com/repos/$repo/releases"
        $tag = (Invoke-WebRequest $releases -usebasicparsing | ConvertFrom-Json)[0].tag_name
    
        $url = "https://github.com/$repo/releases/download/$tag/$file"
        $name = $file.Split(".")[0]
    
        $zip = "$name-$tag.zip"
        $output = "$requirementsFolder\$zip"

        if (![System.IO.File]::Exists($output)) {
    
            Write-Host "INFO: Downloading $file"
            Invoke-WebRequest $url -Out $output
            Write-Host "INFO: Finished Downloading $file successfully"
    
        }
        else {
    
            Write-Host $file "INFO: Already exists...Skipping download."
        }
    
    }

}

function Extract([string]$Path, [string]$Destination) {
    $7z_Application = "$requirementsFolder\7z\7z.exe"
    $7z_Arguments = @(
        'x'                         ## eXtract files with full paths
        '-y'                        ## assume Yes on all queries
        "`"-o$($Destination)`""     ## set Output directory
        "`"$($Path)`""              ## <archive_name>
    )
    & $7z_Application $7z_Arguments | Out-Null
}


# Get script path
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptPath
Write-Host "INFO: Script directory is: $scriptDir"

Write-Host "INFO: Install directory is: $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir

# Acquire files 
$requirementsFolder = "$PSScriptRoot\requirements"
New-Item -ItemType Directory -Force -Path $requirementsFolder
DownloadFiles("downloads")
DownloadFiles("other_downloads")
GithubReleaseFiles

# Prepare 7-zip
if (!(Get-MyModule -name "7Zip4Powershell")) { 
    Install-Module -Name "7Zip4Powershell" -Scope CurrentUser -Force 
}
Expand-7Zip -ArchiveFileName "$requirementsFolder\7z1900.exe" -TargetPath "$requirementsFolder\7z\"


# Install Emulation Station
$emulationStationPackage = [System.IO.Path]::Combine($requirementsFolder, "emulationstation_win32_latest.zip");
$emulationStationInstallFolder = [System.IO.Path]::Combine($InstallDir, "EmulationStation");
if (Test-Path $emulationStationPackage) {
    Extract -Path $emulationStationPackage -Destination $emulationStationInstallFolder | Out-Null
}
else {
    Write-Host "ERROR: $emulationStationPackage not found."
    exit -1
}
$emulationStationBinary = [System.IO.Path]::Combine($emulationStationInstallFolder, "emulationstation.exe")
$emulationStationIcon = [System.IO.Path]::Combine($emulationStationInstallFolder, "icon.ico")
$emulationStationPortableBat = [System.IO.Path]::Combine($emulationStationInstallFolder, "launch_portable.bat")
$emulationStationPortableWindowedBat = [System.IO.Path]::Combine($emulationStationInstallFolder, "launch_portable_windowed.bat")
if (!(Test-Path $emulationStationPortableWindowedBat)) {
    $batContents = "set HOME=%~dp0
    emulationstation.exe --resolution 960 720 --windowed"
    New-Item -Path $emulationStationInstallFolder -Name "launch_portable_windowed.bat" -ItemType File -Value $batContents | Out-Null
}

# Generate Emulation Station config file
& "$emulationStationBinary"
while (!(Test-Path "$env:userprofile\.emulationstation\es_systems.cfg")) { 
    Write-Host "INFO: Checking for config file..."
    Start-Sleep 5
}
Write-Host "INFO: Config file generated"
Stop-Process -Name "emulationstation"

$systemsPath = "$env:userprofile\.emulationstation\systems"

# Prepare Retroarch
$retroArchTempPath = "$requirementsFolder\retroarch"
$retroArchPath = "$systemsPath\retroarch\"
Write-Host "INFO: Setting up RetroArch..."
if (!(Test-Path $retroArchTempPath)) {
    $retroArchPackage = [System.IO.Path]::Combine($requirementsFolder, "RetroArch.7z");
    if (Test-Path $retroArchPackage) {
        Write-Host "INFO: Extracting RetroArch..."
        Extract -Path $retroArchPackage -Destination $retroArchTempPath | Out-Null
    }
    else {
        Write-Host "ERROR: $retroArchBinary not found."
        exit -1
    }
}
Write-Host "INFO: Copying RetroArch files..."
Copy-Item -Path $retroArchTempPath -Destination $retroArchPath -Recurse -Force
$coresPath = [System.IO.Path]::Combine($retroArchPath, "cores");
Write-Host "INFO: RetroArch setup complete."

# NES Setup
$nesCore = "$requirementsFolder\fceumm_libretro.dll.zip"
if (Test-Path $nesCore) {
    Extract -Path $nesCore -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $nesCore not found."
    exit -1
}

# N64 Setup
$n64Core = "$requirementsFolder\parallel_n64_libretro.dll.zip"
if (Test-Path $n64Core) {
    Extract -Path $n64Core -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $n64Core not found."
    exit -1
}

# FBA Setup
$fbaCore = "$requirementsFolder\fbalpha2012_libretro.dll.zip"
if (Test-Path $fbaCore) {
    Extract -Path $fbaCore -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $fbaCore not found."
    exit -1
}

# GBA Setup
$gbaCore = "$requirementsFolder\vba_next_libretro.dll.zip"
if (Test-Path $gbaCore) {
    Extract -Path $gbaCore -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $gbaCore not found."
    exit -1
}

# SNES Setup
$snesCore = "$requirementsFolder\snes9x_libretro.dll.zip"
if (Test-Path $snesCore) {
    Extract -Path $snesCore -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $snesCore not found."
    exit -1
}

# Genesis GX Setup
$mdCore = "$requirementsFolder\genesis_plus_gx_libretro.dll.zip"
if (Test-Path $mdCore) {
    Extract -Path $mdCore -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $mdCore not found."
    exit -1
}

# Game boy Colour Setup
$gbcCore = "$requirementsFolder\gambatte_libretro.dll.zip"
if (Test-Path $gbcCore) {
    Extract -Path $gbcCore -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $gbcCore not found."
    exit -1
}

# Atari2600 Setup
$atari2600Core = "$requirementsFolder\stella_libretro.dll.zip"
if (Test-Path $atari2600Core) {
    Extract -Path $atari2600Core -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $atari2600Core not found."
    exit -1
}

# MAME Setup
$mameCore = "$requirementsFolder\hbmame_libretro.dll.zip"
if (Test-Path $mameCore) {
    Extract -Path $mameCore -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $mameCore not found."
    exit -1
}

# PSX Setup
$psxEmulator = "$requirementsFolder\ePSXe205.zip"
if (Test-Path $psxEmulator) {
    $psxEmulatorPath = "$env:userprofile\.emulationstation\systems\epsxe"
    $psxBiosPath = "$psxEmulatorPath\bios\"
    New-Item -ItemType Directory -Force -Path $psxEmulatorPath | Out-Null
    Extract -Path $psxEmulator -Destination $psxEmulatorPath | Out-Null
}
else {
    Write-Host "ERROR: $psxEmulator not found."
    exit -1
}

# PS2 Setup
$ps2EmulatorMsi = "$requirementsFolder\pcsx2-1.6.0-setup.exe"
$ps2EmulatorTemp = "$requirementsFolder\pcsx2temp"
if (Test-Path $ps2EmulatorMsi) {
    $ps2EmulatorPath = "$env:userprofile\.emulationstation\systems\pcsx2"
    New-Item -ItemType Directory -Force -Path $ps2EmulatorPath | Out-Null
    Extract -Path $ps2EmulatorMsi -Destination $ps2EmulatorTemp | Out-Null
    Move-Item -Path "$ps2EmulatorTemp\`$TEMP\PCSX2 1.6.0" -Destination "$ps2EmulatorPath\PCSX2"
    $ps2Binary = "$ps2EmulatorPath\PCSX2\pcsx2.exe"
    $ps2BiosPath = "$ps2EmulatorPath\bios\"
    New-Item -ItemType Directory -Force -Path $ps2BiosPath | Out-Null
    Remove-Item -Path $ps2EmulatorTemp -Recurse -Force
}
else {
    Write-Host "ERROR: $ps2EmulatorMsi not found."
    exit -1
}

# Dolphin Setup
$dolphinEmulatorMsi = "$requirementsFolder\dolphin-master-5.0-12716-x64.7z"
$dolphinEmulatorTemp = "$requirementsFolder\dolphinTemp"
if (Test-Path $dolphinEmulatorMsi) {
    $dolphinEmulatorPath = "$env:userprofile\.emulationstation\systems\dolphin"
    New-Item -ItemType Directory -Force -Path $dolphinEmulatorPath | Out-Null
    Extract -Path $dolphinEmulatorMsi -Destination $dolphinEmulatorTemp | Out-Null
    Move-Item -Path "$dolphinEmulatorTemp\Dolphin-x64\*" -Destination $dolphinEmulatorPath
    $dolphinBinary = "$dolphinEmulatorPath\Dolphin.exe"
    Remove-Item -Path $dolphinEmulatorTemp -Recurse -Force
}
else {
    Write-Host "ERROR: $dolphinEmulatorMsi not found."
    exit -1
}

# CEMU Setup
$cemuEmulatorZip = "$requirementsFolder\cemu_1.22.0.zip"
$cemuEmulatorTemp = "$requirementsFolder\cemuTemp"
if (Test-Path $cemuEmulatorZip) {
    $cemuEmulatorPath = "$env:userprofile\.emulationstation\systems\cemu"
    New-Item -ItemType Directory -Force -Path $cemuEmulatorPath | Out-Null
    Extract -Path $cemuEmulatorZip -Destination $cemuEmulatorTemp | Out-Null
    Move-Item -Path "$cemuEmulatorTemp\cemu_1.22.0\*" -Destination $cemuEmulatorPath
    $cemuBinary = "$cemuEmulatorPath\Cemu.exe"
    Remove-Item -Path $cemuEmulatorTemp -Recurse -Force
}
else {
    Write-Host "ERROR: $cemuEmulatorZip not found."
    exit -1
}

# NeoGeo Pocket Setup
$ngpCore = "$requirementsFolder\race_libretro.dll.zip"
if (Test-Path $ngpCore) {
    Extract -Path $ngpCore -Destination $coresPath | Out-Null
}
else {
    Write-Host "ERROR: $ngpCore not found."
    exit -1
}

# Start Retroarch and generate a config.
$retroarchExecutable = "$retroArchPath\retroarch.exe"
$retroarchConfigPath = "$retroArchPath\retroarch.cfg"

if (Test-Path $retroarchExecutable) {
    
    Write-Host "INFO: Retroarch executable found, launching"
    Start-Process $retroarchExecutable
    
    while (!(Test-Path $retroarchConfigPath)) { 
        Write-Host "INFO: Checking for retroarch config file"
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
    Write-Host "ERROR: Could not find RetroArch.exe"
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

# Add roms
$romPath = "$env:userprofile\.emulationstation\roms"
New-Item -ItemType Directory -Force -Path $romPath | Out-Null

# Path creation + Open-Source / Freeware Rom population
Write-Host "INFO: Setup NES"
$nesPath = "$romPath\nes"
$nesRom = "$requirementsFolder\assimilate_full.zip" 
if (Test-Path $nesRom) {
    New-Item -ItemType Directory -Force -Path $nesPath | Out-Null
    Extract -Path $nesRom -Destination $nesPath | Out-Null
}
else {
    Write-Host "ERROR: $nesRom not found."
    exit -1
}

Write-Host "INFO: Setup N64"
$n64Path = "$romPath\n64"
$n64Rom = "$requirementsFolder\pom-twin.zip"
if (Test-Path $n64Rom) {
    New-Item -ItemType Directory -Force -Path $n64Path | Out-Null
    Extract -Path $n64Rom -Destination $n64Path | Out-Null
}
else {
    Write-Host "ERROR: $n64Rom not found."
    exit -1
}

Write-Host "INFO: Setup GBA"
$gbaPath = "$romPath\gba"
$gbaRom = "$requirementsFolder\uranus0ev_fix.gba"
if (Test-Path $gbaRom) {
    New-Item -ItemType Directory -Force -Path $gbaPath | Out-Null
    Copy-Item -Path $gbaRom -Destination $gbaPath | Out-Null
}
else {
    Write-Host "ERROR: $gbaRom not found."
    exit -1
}

Write-Host "INFO: Setup Megadrive"
$mdPath = "$romPath\megadrive"
$mdRom = "$requirementsFolder\rickdangerous.gen"
if (Test-Path $mdRom) {
    New-Item -ItemType Directory -Force -Path $mdPath | Out-Null
    Copy-Item -Path $mdRom -Destination $mdPath | Out-Null
}
else {
    Write-Host "ERROR: $mdRom not found."
    exit -1
}

Write-Host "INFO: Setup SNES"
$snesPath = "$romPath\snes"
$snesRom = "$requirementsFolder\N-Warp Daisakusen V1.1.smc"
if (Test-Path $snesRom) {
    New-Item -ItemType Directory -Force -Path $snesPath | Out-Null
    Copy-Item -Path $snesRom -Destination $snesPath | Out-Null
}
else {
    Write-Host "ERROR: $snesRom not found."
    exit -1
}

Write-Host "INFO: Setup PSX"
$psxPath = "$romPath\psx"
$psxRom = "$requirementsFolder\Marilyn_In_the_Magic_World_(010a).7z"
if (Test-Path $psxRom) {
    New-Item -ItemType Directory -Force -Path $psxPath | Out-Null
    Extract -Path $psxRom -Destination $psxPath | Out-Null
}
else {
    Write-Host "ERROR: $psxRom not found."
    exit -1
}

Write-Host "INFO: Setup PS2"
$ps2Path = "$romPath\ps2"
$ps2Rom = "$requirementsFolder\hermes-v.latest-ps2.zip"
if (Test-Path $ps2Rom) {
    New-Item -ItemType Directory -Force -Path $ps2Path | Out-Null
    Extract -Path $ps2Rom -Destination $ps2Path | Out-Null
}
else {
    Write-Host "ERROR: $ps2Rom not found."
    exit -1
}

Write-Host "INFO: Setup Gameboy"
$gbPath = "$romPath\gb"
New-Item -ItemType Directory -Force -Path $gbPath | Out-Null

Write-Host "INFO: Setup Gameboy Color"
$gbcPath = "$romPath\gbc"
$gbcRom = "$requirementsFolder\star_heritage.zip" 
if (Test-Path $gbcRom) {
    New-Item -ItemType Directory -Force -Path $gbcPath | Out-Null
    Extract -Path $gbcRom -Destination $gbcPath | Out-Null
}
else {
    Write-Host "ERROR: $gbcRom not found."
    exit -1
}

Write-Host "INFO: Setup Sega Mastersystem"
$masterSystemPath = "$romPath\mastersystem"
$masterSystemRom = "$requirementsFolder\WahMunchers-SMS-R2.zip" 
if (Test-Path $masterSystemRom) {
    New-Item -ItemType Directory -Force -Path $masterSystemPath | Out-Null
    Extract -Path $masterSystemRom -Destination $masterSystemPath | Out-Null
}
else {
    Write-Host "ERROR: $masterSystemRom not found."
    exit -1
}

Write-Host "INFO: Setup FBA"
$fbaPath = "$romPath\fba"
New-Item -ItemType Directory -Force -Path $fbaPath | Out-Null

Write-Host "INFO: Setup Atari 2600"
$atari2600Path = "$romPath\atari2600"
$atari2600Rom = "$requirementsFolder\ramless_pong.bin"
if (Test-Path $atari2600Rom) {
    New-Item -ItemType Directory -Force -Path $atari2600Path | Out-Null
    Copy-Item -Path $atari2600Rom -Destination $atari2600Path | Out-Null
}
else {
    Write-Host "ERROR: $atari2600Rom not found."
    exit -1
}

Write-Host "INFO: Setup MAME"
$mamePath = "$romPath\mame"
New-Item -ItemType Directory -Force -Path $mamePath | Out-Null

# WIP: Need to test and find freeware games for these emulators.
# Need to write a bat to boot these
Write-Host "INFO: Setup ScummVm"
$scummVmPath = "$romPath\scummvm"
New-Item -ItemType Directory -Force -Path $scummVmPath | Out-Null

$wiiuPath = "$romPath\wiiu"
New-Item -ItemType Directory -Force -Path $wiiuPath | Out-Null

Write-Host "INFO: Setup NEO-GEO Pocket"
$neogeoPocketPath = "$romPath\ngp"
$ngpRom = "$requirementsFolder\neopocket.zip"
if (Test-Path $ngpRom) {
    New-Item -ItemType Directory -Force -Path $neogeoPocketPath | Out-Null
    Extract -Path $ngpRom -Destination $neogeoPocketPath | Out-Null
}
else {
    Write-Host "ERROR: $ngpRom not found."
    exit -1
}

Write-Host "INFO: Setup NEO-GEO"
$neogeoPath = "$romPath\neogeo"
New-Item -ItemType Directory -Force -Path $neogeoPath | Out-Null

Write-Host "INFO: Setup MSX"
$msxPath = "$romPath\msx"
$msxCore = "$requirementsFolder\fmsx_libretro.dll.zip"
if (Test-Path $msxCore) {
    Extract -Path $msxCore -Destination $coresPath | Out-Null
    New-Item -ItemType Directory -Force -Path $msxPath | Out-Null
}
else {
    Write-Host "ERROR: $msxCore not found."
    exit -1
}

Write-Host "INFO: Setup Commodore 64"
$commodore64Path = "$romPath\c64"
$commodore64Core = "$requirementsFolder\vice_x64_libretro.dll.zip"
if (Test-Path $commodore64Core) {
    Extract -Path $commodore64Core -Destination $coresPath | Out-Null
    New-Item -ItemType Directory -Force -Path $commodore64Path | Out-Null
}
else {
    Write-Host "ERROR: $commodore64Core not found."
    exit -1
}

Write-Host "INFO: Setup Commodore Amiga"
$amigaPath = "$romPath\amiga"
$amigaCore = "$requirementsFolder\puae_libretro.dll.zip"
if (Test-Path $amigaCore) {
    Extract -Path $amigaCore -Destination $coresPath | Out-Null
    New-Item -ItemType Directory -Force -Path $amigaPath | Out-Null
}
else {
    Write-Host "ERROR: $amigaCore not found."
    exit -1
}

Write-Host "INFO: Setup Atari 7800"
$atari7800Path = "$romPath\atari7800"
$atari7800Core = "$requirementsFolder\prosystem_libretro.dll.zip"
if (Test-Path $atari7800Core) {
    Extract -Path $atari7800Core -Destination $coresPath | Out-Null
    New-Item -ItemType Directory -Force -Path $atari7800Path | Out-Null
}
else {
    Write-Host "ERROR: $atari7800Core not found."
    exit -1
}

Write-Host "INFO: Setup Wii/GameCube"
$gcPath = "$romPath\gc"
$wiiPath = "$romPath\wii"
$wiiRom = "$requirementsFolder\Homebrew.Channel.-.OHBC.wad"
New-Item -ItemType Directory -Force -Path $gcPath | Out-Null
New-Item -ItemType Directory -Force -Path $wiiPath | Out-Null
if (Test-Path $wiiRom) {
    Copy-Item $wiiRom $wiiPath | Out-Null
}
else {
    Write-Host "ERROR: $wiiRom not found."
    exit -1
}

Write-Host "INFO: Setting up Emulation Station Config"
$esConfigFile = "$env:userprofile\.emulationstation\es_systems.cfg"
$newConfig = "<systemList>
    <system>
        <name>nes</name>
        <fullname>Nintendo Entertainment System</fullname>
        <path>$nesPath</path>
        <extension>.nes .NES</extension>
        <command>$retroarchExecutable -L $coresPath\fceumm_libretro.dll %ROM%</command>
        <platform>nes</platform>
        <theme>nes</theme>
    </system>
    <system>
        <fullname>Super Nintendo</fullname>
        <name>snes</name>
        <path>$snesPath</path>
        <extension>.smc .sfc .fig .swc .SMC .SFC .FIG .SWC</extension>
        <command>$retroarchExecutable -L $coresPath\snes9x_libretro.dll %ROM%</command>
        <platform>snes</platform>
        <theme>snes</theme>
    </system>
    <system>
        <fullname>Nintendo 64</fullname>
        <name>n64</name>
        <path>$n64Path</path>
        <extension>.z64 .Z64 .n64 .N64 .v64 .V64</extension>
        <command>$retroarchExecutable -L $coresPath\parallel_n64_libretro.dll %ROM%</command>
        <platform>n64</platform>
        <theme>n64</theme>
    </system>
    <system>
        <fullname>Gamecube</fullname>
        <name>gc</name>
        <path>$gcPath</path>
        <extension>.iso .ISO</extension>
        <command>$dolphinBinary -e `"%ROM_RAW%`"</command>
        <platform>gc</platform>
        <theme>gc</theme>
    </system>
    <system>
        <name>wii</name>
        <fullname>Nintendo Wii</fullname>
        <path>$wiiPath</path>
        <extension>.iso .ISO .wad .WAD</extension>
        <command>$dolphinBinary -e `"%ROM_RAW%`"</command>
        <platform>wii</platform>
        <theme>wii</theme>  
    </system>
    <system>
        <fullname>Game Boy</fullname>
        <name>gb</name>
        <path>$gbPath</path>
        <extension>.gb .zip .ZIP .7z</extension>
        <command>$retroarchExecutable -L $coresPath\gambatte_libretro.dll %ROM%</command>
        <platform>gb</platform>
        <theme>gb</theme>
    </system>
    <system>
        <fullname>Game Boy Color</fullname>
        <name>gbc</name>
        <path>$gbcPath</path>
        <extension>.gbc .GBC .zip .ZIP</extension>
        <command>$retroarchExecutable -L $coresPath\gambatte_libretro.dll %ROM%</command>
        <platform>gbc</platform>
        <theme>gbc</theme>
    </system>
    <system>
        <fullname>Game Boy Advance</fullname>
        <name>gba</name>
        <path>$gbaPath</path>
        <extension>.gba .GBA</extension>
        <command>$retroarchExecutable -L $coresPath\vba_next_libretro.dll %ROM%</command>
        <platform>gba</platform>
        <theme>gba</theme>
    </system>
    <system>
        <fullname>Playstation</fullname>
        <name>psx</name>
        <path>$psxPath</path>
        <extension>.cue .iso .pbp .CUE .ISO .PBP</extension>
        <command>${psxEmulatorPath}ePSXe.exe -bios ${psxBiosPath}SCPH1001.BIN -nogui -loadbin %ROM%</command>
        <platform>psx</platform>
        <theme>psx</theme>
    </system>
    <system>
        <fullname>Playstation 2</fullname>
        <name>ps2</name>
        <path>$ps2Path</path>
        <extension>.iso .img .bin .mdf .z .z2 .bz2 .dump .cso .ima .gz</extension>
        <command>${ps2Binary} %ROM% --fullscreen --nogui</command>
        <platform>ps2</platform>
        <theme>ps2</theme>
    </system>
    <system>
        <fullname>MAME</fullname>
        <name>mame</name>
        <path>$mamePath</path>
        <extension>.zip .ZIP</extension>
        <command>$retroarchExecutable -L $coresPath\hbmame_libretro.dll %ROM%</command>
        <platform>mame</platform>
        <theme>mame</theme>
    </system>
    <system>
        <fullname>Final Burn Alpha</fullname>
        <name>fba</name>
        <path>$fbaPath</path>
        <extension>.zip .ZIP .fba .FBA</extension>
        <command>$retroarchExecutable -L $coresPath\fbalpha2012_libretro.dll %ROM%</command>
        <platform>arcade</platform>
        <theme></theme>
    </system>
    <system>
        <fullname>Amiga</fullname>
        <name>amiga</name>
        <path>$amigaPath</path>
        <extension>.adf .ADF</extension>
        <command>$retroarchExecutable -L $coresPath\puae_libretro.dll %ROM%</command>
        <platform>amiga</platform>
        <theme>amiga</theme>
    </system>
    <system>
        <fullname>Atari 2600</fullname>
        <name>atari2600</name>
        <path>$atari2600Path</path>
        <extension>.a26 .bin .rom .A26 .BIN .ROM</extension>
        <command>$retroarchExecutable -L $coresPath\stella_libretro.dll %ROM%</command>
        <platform>atari2600</platform>
        <theme>atari2600</theme>
    </system>
    <system>
        <fullname>Atari 7800 Prosystem</fullname>
        <name>atari7800</name>
        <path>$atari7800Path</path>
        <extension>.a78 .bin .A78 .BIN</extension>
        <command>$retroarchExecutable -L $coresPath\prosystem_libretro.dll %ROM%</command>
        <platform>atari7800</platform>
        <theme>atari7800</theme>
    </system>
    <system>
        <fullname>Commodore 64</fullname>
        <name>c64</name>
        <path>$commodore64Path</path>
        <extension>.crt .d64 .g64 .t64 .tap .x64 .zip .CRT .D64 .G64 .T64 .TAP .X64 .ZIP</extension>
        <command>$retroarchExecutable -L $coresPath\vice_x64_libretro.dll %ROM%</command>
        <platform>c64</platform>
        <theme>c64</theme>
    </system>
    <system>
        <fullname>Sega Mega Drive / Genesis</fullname>
        <name>megadrive</name>
        <path>$mdPath</path>
        <extension>.smd .SMD .bin .BIN .gen .GEN .md .MD .zip .ZIP</extension>
        <command>$retroarchExecutable -L $coresPath\genesis_plus_gx_libretro.dll %ROM%</command>
        <platform>genesis,megadrive</platform>
        <theme>megadrive</theme>
    </system>
    <system>
        <fullname>Sega Master System</fullname>
        <name>mastersystem</name>
        <path>$masterSystemPath</path>
        <extension>.bin .sms .zip .BIN .SMS .ZIP</extension>
        <command>$retroarchExecutable -L $coresPath\genesis_plus_gx_libretro.dll %ROM%</command>
        <platform>mastersystem</platform>
        <theme>mastersystem</theme>
    </system>
    <system>
        <fullname>MSX</fullname>
        <name>msx</name>
        <path>$msxPath</path>
        <extension>.col .dsk .mx1 .mx2 .rom .COL .DSK .MX1 .MX2 .ROM</extension>
        <command>$retroarchExecutable -L $coresPath\fmsx_libretro.dll %ROM%</command>
        <platform>msx</platform>
        <theme>msx</theme>
    </system>
    <system>
        <name>neogeo</name>
        <fullname>Neo Geo</fullname>
        <path>$neogeoPath</path>
        <extension>.zip .ZIP</extension>
        <command>$retroarchExecutable -L $coresPath\fbalpha2012_libretro.dll %ROM%</command>        
        <platform>neogeo</platform>
        <theme>neogeo</theme>
    </system>
    <system>
        <fullname>Neo Geo Pocket</fullname>
        <name>ngp</name>
        <path>$neogeoPocketPath</path>
        <extension>.ngp .ngc .zip .ZIP</extension>
        <command>$retroarchExecutable -L $coresPath\race_libretro.dll %ROM%</command>        
        <platform>ngp</platform>
        <theme>ngp</theme>
    </system>
    <system>
        <fullname>ScummVM</fullname>
        <name>scummvm</name>
        <path>$scummVmPath</path>
        <extension>.bat .BAT</extension>
        <command>%ROM%</command>
        <platform>pc</platform>
        <theme>scummvm</theme>
    </system>
    <system>
        <name>wiiu</name>
        <fullname>Nintendo Wii U</fullname>
        <path>$wiiuPath</path>
        <extension>.rpx .RPX</extension>
        <command>START /D $cemuBinary -f -g `"%ROM_RAW%`"</command>
        <platform>wiiu</platform>
        <theme>wiiu</theme>
</system>
</systemList>
"
Set-Content $esConfigFile -Value $newConfig

Write-Host "INFO: Setting up Emulation Station theme recalbox-backport"
$themesPath = "$env:userprofile\.emulationstation\themes\recalbox-backport\"
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

Write-Host "INFO: Update EmulationStation binaries"
$updatedEmulationStatonBinaries = "$requirementsFolder\EmulationStation-Win32-continuous-master.zip"
if (Test-Path $updatedEmulationStatonBinaries) {
    Extract -Path $updatedEmulationStatonBinaries -Destination $emulationStationInstallFolder | Out-Null
}
else {
    Write-Host "ERROR: $updatedEmulationStatonBinaries not found."
    exit -1
}

Write-Host "INFO: Generate ES settings file with favorites enabled."
$esConfigFile = "$env:userprofile\.emulationstation\es_settings.cfg"
$newSettingsConfig = "<?xml version='1.0'?>
<bool name='BackgroundJoystickInput' value='false' />
<bool name='CaptionsCompatibility' value='true' />
<bool name='DrawFramerate' value='false' />
<bool name='EnableSounds' value='true' />
<bool name='MoveCarousel' value='true' />
<bool name='ParseGamelistOnly' value='false' />
<bool name='QuickSystemSelect' value='true' />
<bool name='SaveGamelistsOnExit' value='true' />
<bool name='ScrapeRatings' value='true' />
<bool name='ScreenSaverControls' value='true' />
<bool name='ScreenSaverOmxPlayer' value='false' />
<bool name='ShowHelpPrompts' value='true' />
<bool name='ShowHiddenFiles' value='false' />
<bool name='SlideshowScreenSaverCustomImageSource' value='false' />
<bool name='SlideshowScreenSaverRecurse' value='false' />
<bool name='SlideshowScreenSaverStretch' value='false' />
<bool name='SortAllSystems' value='false' />
<bool name='StretchVideoOnScreenSaver' value='false' />
<bool name='UseCustomCollectionsSystem' value='true' />
<bool name='VideoAudio' value='true' />
<bool name='VideoOmxPlayer' value='false' />
<int name='MaxVRAM' value='100' />
<int name='ScraperResizeHeight' value='0' />
<int name='ScraperResizeWidth' value='400' />
<int name='ScreenSaverSwapImageTimeout' value='10000' />
<int name='ScreenSaverSwapVideoTimeout' value='30000' />
<int name='ScreenSaverTime' value='300000' />
<string name='AudioDevice' value='Master' />
<string name='CollectionSystemsAuto' value='favorites' />
<string name='CollectionSystemsCustom' value='' />
<string name='GamelistViewStyle' value='automatic' />
<string name='OMXAudioDev' value='both' />
<string name='PowerSaverMode' value='disabled' />
<string name='Scraper' value='TheGamesDB' />
<string name='ScreenSaverBehavior' value='dim' />
<string name='ScreenSaverGameInfo' value='never' />
<string name='SlideshowScreenSaverBackgroundAudioFile' value='$env:userprofile/.emulationstation/slideshow/audio/slideshow_bg.wav' />
<string name='SlideshowScreenSaverImageDir' value='$env:userprofile/.emulationstation/slideshow/image' />
<string name='SlideshowScreenSaverImageFilter' value='.png,.jpg' />
<string name='ThemeSet' value='recalbox-backport' />
<string name='TransitionStyle' value='fade' />

"

Set-Content $esConfigFile -Value $newSettingsConfig
$requiredTmpFolder = "$env:userprofile\.emulationstation\tmp\"
New-Item -ItemType Directory -Force -Path $requiredTmpFolder | Out-Null

Write-Host "INFO: Generating Dolphin Config"
$dolphinConfigFile = "$env:userprofile\.emulationstation\systems\retroarch\saves\User\Config\Dolphin.ini"
$dolphinConfigFolder = "$env:userprofile\.emulationstation\systems\retroarch\saves\User\Config\"
$dolphinConfigFileContent = "[General]
LastFilename = 
ShowLag = False
ShowFrameCount = False
ISOPaths = 0
RecursiveISOPaths = False
NANDRootPath = 
DumpPath = 
WirelessMac = 
WiiSDCardPath = $env:userprofile\.emulationstation\systems\retroarch\saves\User\Wii\sd.raw
[Interface]
ConfirmStop = True
UsePanicHandlers = True
OnScreenDisplayMessages = True
HideCursor = False
AutoHideCursor = False
MainWindowPosX = -2147483648
MainWindowPosY = -2147483648
MainWindowWidth = -1
MainWindowHeight = -1
LanguageCode = 
ShowToolbar = True
ShowStatusbar = True
ShowLogWindow = False
ShowLogConfigWindow = False
ExtendedFPSInfo = False
ThemeName = Clean
PauseOnFocusLost = False
DisableTooltips = False
[Display]
FullscreenResolution = Auto
Fullscreen = False
RenderToMain = True
RenderWindowXPos = -1
RenderWindowYPos = -1
RenderWindowWidth = 640
RenderWindowHeight = 480
RenderWindowAutoSize = False
KeepWindowOnTop = False
ProgressiveScan = False
PAL60 = False
DisableScreenSaver = False
ForceNTSCJ = False
[GameList]
ListDrives = False
ListWad = True
ListElfDol = True
ListWii = True
ListGC = True
ListJap = True
ListPal = True
ListUsa = True
ListAustralia = True
ListFrance = True
ListGermany = True
ListItaly = True
ListKorea = True
ListNetherlands = True
ListRussia = True
ListSpain = True
ListTaiwan = True
ListWorld = True
ListUnknown = True
ListSort = 3
ListSortSecondary = 0
ColumnPlatform = True
ColumnBanner = True
ColumnNotes = True
ColumnFileName = False
ColumnID = False
ColumnRegion = True
ColumnSize = True
ColumnState = True
[Core]
HLE_BS2 = True
TimingVariance = 40
CPUCore = 1
Fastmem = True
CPUThread = True
DSPHLE = True
SyncOnSkipIdle = True
SyncGPU = True
SyncGpuMaxDistance = 200000
SyncGpuMinDistance = -200000
SyncGpuOverclock = 1.00000000
FPRF = False
AccurateNaNs = False
DefaultISO = 
DVDRoot = 
Apploader = 
EnableCheats = False
SelectedLanguage = 0
OverrideGCLang = False
DPL2Decoder = False
Latency = 2
AudioStretch = False
AudioStretchMaxLatency = 80
MemcardAPath = $env:userprofile\.emulationstation\systems\retroarch\saves\User\GC\MemoryCardA.USA.raw
MemcardBPath = $env:userprofile\.emulationstation\systems\retroarch\saves\User\GC\MemoryCardB.USA.raw
AgpCartAPath = 
AgpCartBPath = 
SlotA = 1
SlotB = 255
SerialPort1 = 255
BBA_MAC = 
SIDevice0 = 6
AdapterRumble0 = True
SimulateKonga0 = False
SIDevice1 = 0
AdapterRumble1 = True
SimulateKonga1 = False
SIDevice2 = 0
AdapterRumble2 = True
SimulateKonga2 = False
SIDevice3 = 0
AdapterRumble3 = True
SimulateKonga3 = False
WiiSDCard = False
WiiKeyboard = False
WiimoteContinuousScanning = False
WiimoteEnableSpeaker = False
RunCompareServer = False
RunCompareClient = False
EmulationSpeed = 1.00000000
FrameSkip = 0x00000000
Overclock = 1.00000000
OverclockEnable = False
GFXBackend = OGL
GPUDeterminismMode = auto
PerfMapDir = 
EnableCustomRTC = False
CustomRTCValue = 0x386d4380
[Movie]
PauseMovie = False
Author = 
DumpFrames = False
DumpFramesSilent = False
ShowInputDisplay = False
ShowRTC = False
[DSP]
EnableJIT = False
DumpAudio = False
DumpAudioSilent = False
DumpUCode = False
Backend = Libretro
Volume = 100
CaptureLog = False
[Input]
BackgroundInput = False
[FifoPlayer]
LoopReplay = False
[Analytics]
ID = 
Enabled = False
PermissionAsked = False
[Network]
SSLDumpRead = False
SSLDumpWrite = False
SSLVerifyCertificates = True
SSLDumpRootCA = False
SSLDumpPeerCert = False
[BluetoothPassthrough]
Enabled = False
VID = -1
PID = -1
LinkKeys = 
[USBPassthrough]
Devices = 
[Sysconf]
SensorBarPosition = 1
SensorBarSensitivity = 50331648
SpeakerVolume = 88
WiimoteMotor = True
WiiLanguage = 1
AspectRatio = 1
Screensaver = 0

"
New-Item $dolphinConfigFolder -ItemType directory | Out-Null
Write-Output $dolphinConfigFileContent  > $dolphinConfigFile

# TO-DO: Review if this is still needed or not
# # https://www.ngemu.com/threads/epsxe-2-0-5-startup-crash-black-screen-fix-here.199169/
# # https://www.youtube.com/watch?v=fY89H8fLFSc
# $path = 'HKCU:\SOFTWARE\epsxe\config'
# New-Item -Path $path -Force | Out-Null
# Set-ItemProperty -Path $path -Name 'CPUOverclocking' -Value '10'

Write-Host "INFO: Adding scraper in $romPath"
$scraperZip = "$requirementsFolder\scraper_windows_amd64*.zip"
if (Test-Path $scraperZip) {
    Extract -Path $scraperZip -Destination $romPath | Out-Null
}
else {
    Write-Host "ERROR: $scraperZip not found."
    exit -1
}

# Create Shortcuts
$userProfileVariable = Get-ChildItem Env:UserProfile
if ($Portable) {
    Write-Host "INFO: Moving '$env:userprofile\.emulationstation' to '$emulationStationInstallFolder\.emulationstation'..."
    Robocopy "$env:userprofile\.emulationstation" "$emulationStationInstallFolder\.emulationstation" /MOVE /E /NFL /NDL /NJH /NJS /nc /ns
    $romsShortcut = "$emulationStationInstallFolder\.emulationstation\roms"
    $coresShortcut = "$emulationStationInstallFolder\.emulationstation\systems\retroarch\cores"
}
else {
    $romsShortcut = $userProfileVariable.Value + "\.emulationstation\roms"
    $coresShortcut = $userProfileVariable.Value + "\.emulationstation\systems\retroarch\cores"
}

Write-Host "INFO: Creating shortcuts"
$wshshell = New-Object -ComObject WScript.Shell

$lnkRoms = $wshshell.CreateShortcut("$InstallDir\Roms.lnk")
$lnkRoms.TargetPath = $romsShortcut
$lnkRoms.Save() 

$lnkCores = $wshshell.CreateShortcut("$InstallDir\Cores.lnk")
$lnkCores.TargetPath = $coresShortcut
$lnkCores.Save() 

$lnkEmulationStation = $wshshell.CreateShortcut("$InstallDir\EmulationStation.lnk")
$lnkEmulationStation.WorkingDirectory = $emulationStationInstallFolder
$lnkEmulationStation.IconLocation = $emulationStationIcon
if ($Portable) {
    $lnkEmulationStation.TargetPath = $emulationStationPortableBat
}
else {
    $lnkEmulationStation.TargetPath = $emulationStationBinary
}
$lnkEmulationStation.Save() 

$lnkWindowed = $wshshell.CreateShortcut("$InstallDir\EmulationStation (Windowed).lnk")
$lnkWindowed.WorkingDirectory = $emulationStationInstallFolder
$lnkWindowed.IconLocation = $emulationStationIcon
if ($Portable) {
    $lnkWindowed.TargetPath = $emulationStationPortableWindowedBat
}
else {
    $lnkWindowed.TargetPath = $emulationStationBinary
    $lnkWindowed.Arguments = "--resolution 1366 768 --windowed"
}
$lnkWindowed.Save() 

$desktop = [System.Environment]::GetFolderPath('Desktop')
$lnkEmulationStationDesktop = $wshshell.CreateShortcut("$desktop\EmulationStation.lnk")
$lnkEmulationStationDesktop.WorkingDirectory = $emulationStationInstallFolder
$lnkEmulationStationDesktop.IconLocation = $emulationStationIcon
if ($Portable) {
    $lnkEmulationStationDesktop.TargetPath = $emulationStationPortableBat
}
else {
    $lnkEmulationStationDesktop.TargetPath = $emulationStationBinary
}
$lnkEmulationStationDesktop.Save() 


$lnkEmulationStationWindowedDesktop = $wshshell.CreateShortcut("$desktop\EmulationStation (Windowed).lnk")
$lnkEmulationStationWindowedDesktop.WorkingDirectory = $emulationStationInstallFolder
$lnkEmulationStationWindowedDesktop.IconLocation = $emulationStationIcon
if ($Portable) {
    $lnkEmulationStationWindowedDesktop.TargetPath = $emulationStationPortableWindowedBat
}
else {
    $lnkEmulationStationWindowedDesktop.TargetPath = $emulationStationBinary
    $lnkEmulationStationWindowedDesktop.Arguments = "--resolution 1366 768 --windowed"
}
$lnkEmulationStationWindowedDesktop.Save() 

Write-Host "INFO: Setup completed"