Function Get-MyModule {
    Param(
        [string]$name
    )

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
    param (
        [parameter(Mandatory = $true)][string]$downloadsFile,
        [parameter(Mandatory = $true)][string]$downloadOption, 
        [parameter(Mandatory = $true)][string]$targetDir
    )
    
    Write-Host "Starting downloading of '$downloadOption' from '$downloadsFile'..."

    Get-Content $downloadsFile | ConvertFrom-Json | Select-Object -expand $downloadOption | ForEach-Object {
    
        $url = $_.url
        $file = $_.file
        $output = "$targetDir\$file"

        if (![System.IO.File]::Exists($output)) {
    
            Write-Host "INFO: Downloading $file"
            Invoke-WebRequest $url -Out $output   
        }
        else {
            Write-Host $file "INFO: Already exists... skipping download."
        }
    }
}

function GithubReleaseFiles {
    Param(
        [String]$downloadsFile,
        [String]$targetDir
    )

    Write-Host "Starting downloading of GitHub release files from '$downloadsFile'..."
    
    Get-Content $downloadsFile | ConvertFrom-Json | Select-Object -expand releases | ForEach-Object {

        $repo = $_.repo
        $file = $_.file
        $releases = "https://api.github.com/repos/$repo/releases"
        $tag = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)[0].tag_name
    
        $url = "https://github.com/$repo/releases/download/$tag/$file"
        $name = $file.Split(".")[0]
    
        $zip = "$name-$tag.zip"
        $output = "$targetDir\$zip"

        if (![System.IO.File]::Exists($output)) {
    
            Write-Host "INFO: Downloading $file"
            Invoke-WebRequest $url -Out $output    
        }
        else {
            Write-Host $file "INFO: Already exists... skipping download."
        }
    }
}

function Extract([string]$Path, [string]$Destination) {
    $sevenZipApplication = "$requirementsFolder\7z\7z.exe"
    $sevenZipArguments = @(
        'x'                     ## eXtract files with full paths
        '-y'                    ## assume Yes on all queries
        "`"-o$($Destination)`"" ## set Output directory
        "`"$($Path)`""          ## <archive_name>
    )
    & $sevenZipApplication $sevenZipArguments | Out-Null
}

function CopyCore {
    Param(
        [String]$fromFolder,
        [String]$coreZip,
        [String]$coresPath
    )
    $core = "$fromFolder\$coreZip"
    if (Test-Path $core) {
        Extract -Path $core -Destination $coresPath | Out-Null
    }
    else {
        Write-Host "ERROR: $core not found."
        exit -1
    }
}

function SetupZip {
    param (
        [String]$zipFile,
        [string]$zipFolderToCopy,
        [String]$targetFolder
    )
    # System Setup
    if (Test-Path $zipFile) {
        # Create target directory
        New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
        # Extract to a temp folder
        $tempFolder = "$requirementsFolder/temp/"
        Extract -Path $zipFile -Destination $tempFolder | Out-Null
        # Move files to the final directory in systems folder
        if ($zipFolderToCopy -eq "") {
            Robocopy.exe $tempFolder $targetFolder /E /NFL /NDL /NJH /NJS /nc /ns /np /MOVE | Out-Null
        }
        else {
            Robocopy.exe $tempFolder/$zipFolderToCopy $targetFolder /E /NFL /NDL /NJH /NJS /nc /ns /np /MOVE | Out-Null
            Remove-Item $tempFolder -Force -Recurse
        }
    }
    else {
        Write-Host "ERROR: $zipFile not found."
        exit -1
    }
}

function Add-Rom {
    param(
        [String]$rom,
        [string]$path
    )
    if ([String]::IsNullOrWhiteSpace($rom)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
    else {
        if (Test-Path $rom) {
            New-Item -ItemType Directory -Force -Path $path | Out-Null
            if ( $rom.EndsWith("zip") -or $rom.EndsWith("7z") -or $rom.EndsWith("gz") ) {
                Extract -Path $rom -Destination $path | Out-Null
            }
            else {
                Move-Item -Path $rom -Destination $path -Force | Out-Null
            }

        }
        else {
            Write-Host "ERROR: $rom not found."
            exit -1
        }
    }
}


function Write-ESSystemsConfig {
    param(
        [String] $ConfigFile,
        [hashtable] $Systems,
        [string] $RomsPath
    )

    $xmlWriter = New-Object System.XMl.XmlTextWriter($ConfigFile, $Null)
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $XmlWriter.IndentChar = "`t"
    $xmlWriter.WriteStartDocument()
    $xmlWriter.WriteStartElement('systemList')
    
    foreach ($item in $Systems.GetEnumerator()) {
        $xmlWriter.WriteStartElement('system')
        $xmlWriter.WriteElementString('name', $item.Key)
        $xmlWriter.WriteElementString('fullname', $item.Value[0])
        $xmlWriter.WriteElementString('path', "$RomsPath/" + $item.Key)
        $xmlWriter.WriteElementString('extension', $item.Value[1])
        $xmlWriter.WriteElementString('command', $item.Value[2])
        $xmlWriter.WriteElementString('platform', $item.Value[3])
        $xmlWriter.WriteElementString('theme', $item.Value[4])
        $xmlWriter.WriteEndElement()
    }
    $xmlWriter.WriteEndElement()
    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()
}

function Add-Shortcut {
    param (
        [String]$ShortcutLocation,
        [String]$ShortcutTarget,
        [String]$ShortcutIcon,
        [String]$WorkingDir
    )
    $wshshell = New-Object -ComObject WScript.Shell
    $link = $wshshell.CreateShortcut($ShortcutLocation)
    $link.TargetPath = $ShortcutTarget
    if(-Not [String]::IsNullOrEmpty($WorkingDir)) {
        $link.WorkingDirectory = $WorkingDir
    }
    if(-Not [String]::IsNullOrEmpty($ShortcutIcon)) {
        $link.IconLocation = $ShortcutIcon
    }
    $link.Save() 
}