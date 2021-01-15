<img src="icon.png" align="right" />

# EmulationStation configured for Windows 10

![Script working](https://github.com/ferarias/win10_emulation_station/workflows/Build/badge.svg)

An auto-installer to set up a **portable** installation of [Emulation Station](http://www.emulationstation.org) on a 64-bit version of Windows 10.

## Features

- Based upon the fabulous work by [Francommit](https://github.com/Francommit) in the [original version](https://github.com/Francommit/win10_emulation_station).
- Uses an up to date version of Emulation Station from the Raspberry Pi branch
- Auto populates emulators with free roms
- Auto installs a popular theme with support for adding 'Favorites'
- Adds several useful shortcuts to the user's Desktop
- Adds in a game content scraper (scraper.exe in ROMs folder)


## Steps

### Option A. Easy setup:

You can easily install everything by copying the following text and pasting it into a powershell window.
```
Set-ExecutionPolicy Bypass -Scope Process -Force;[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;$tag = (Invoke-WebRequest "https://api.github.com/repos/ferarias/win10_emulation_station/releases" -UseBasicParsing | ConvertFrom-Json)[0].tag_name;Invoke-WebRequest "https://github.com/ferarias/win10_emulation_station/archive/$tag.zip" -OutFile "ESWin10.zip";Expand-Archive .\ESWin10.zip;Move-Item .\ESWin10\win* .\ESWin10\setup;.\ESWin10\setup\install.ps1

```

### Option B. Detailed steps (recommended)

- Download the [Latest Release](https://github.com/ferarias/win10_emulation_station/releases/latest) (Source code zip or tgz)
- Extract to a convenient folder. E.g.: c:\tmp
- Start a PowerShell and CD into the extracted directory
- You can run the installation process using the `.\install.ps1` script. The syntax is as follows:  
```powershell
install.ps1 [-InstallDir] <string> [[-CustomRomsFolder] <string>] [<CommonParameters>]
```
Example:  
```powershell
.\install.ps1 D:\emu
```

If you already have a folder with ROM files, use the second parameter to specify it:
```powershell
.\install.ps1 D:\emu D:\ROM
```
- Script has completed when Powershell spits out:
```
INFO: Setup completed
```



## Running

1. Double-click the `EmulationStation` shortcut to launch
2. To access your ROMS follow the shortcut named `Roms` in the installation folder.
3. To access your RetroArch cores follow the shortcut named `Cores` in the installation folder.
4. If you want to open EmulationStation *in a window* instead of fullscreen, double-click the `EmulationStation (Windowed)` shortcut.




## Troubleshooting

- If the controller is not working in game, configure Input in Retroarch (%UserProfile%\\.emulationstation\systems\retroarch\retroarch.exe)
- PSX and PS2 Homebrew Games won't load unless you acquire the bios's and add them to the bios folder (%UserProfile%\\.emulationstation\systems\epsxe\bios and %UserProfile%\\.emulationstation\systems\pcsx2\bios)
- PSX and PS2 also require manual configuration for controllers (%UserProfile%\\.emulationstation\systems\epsxe\ePSXe.exe and %UserProfile%\\.emulationstation\systems\pcsx2\pcsx2.exe)
- If the script fails for whatever reason delete the contents of %UserProfile%\\.emulationstation and try again.
- Emulation Station may crash when you return to it from a external progam, ensure your graphics drivers are up to date.
- Launching a Retroarch rom may return you to ES, you're probably on a 32-bit verison of Windows and need to acquire seperate cores.
- Powershell commands may fail, ensure your Powershell session is in Admin mode.
- If Powershell complains about syntax you're probably somehow running a Powershell version lower than 5. Run 'choco install powershell -y' to update.
- If you are using Xbox controllers and having trouble setting the guide button as hotkey, locate the file (%UserProfile%\\.emulationstation\es_input.cfg and change the line for hotkeyenable to ```<input id="5" name="hotkeyenable" type="button" value="10" />```
- If you are unable to run script from context menu (right mouse button), revert default "Open with" to Notepad

## Uninstall

## Special Thanks

- [Francommit](https://github.com/Francommit) for the [original version](https://github.com/Francommit/win10_emulation_station) of the scripts.
- [jrassa](https://github.com/jrassa/) for his up to date [compiled version of Emulation Station](https://github.com/jrassa/EmulationStation).
- [Nesworld](http://www.nesworld.com/) for their open-source NES roms.
- [Libretro](https://www.libretro.com/) for their RetroArch version.
- [OpenEmu](https://github.com/OpenEmu/) for their [Open-Source rom collection](https://github.com/OpenEmu/OpenEmu-Update) work.
- [fonic](https://github.com/fonic/) for his [theme](https://github.com/fonic/recalbox-backport).
- [sselph](https://github.com/sselph) for his awesome [scraper](https://github.com/sselph/scraper).
