Function Get-MyModule {
    Param(
        [string]$name
    )

    if (-not(Get-Module -name $name)) {
        if (Get-Module -ListAvailable |
            Where-Object { $_.name -eq $name }) {
            Import-Module -Name $name
            $true
        } 
        else { $false }
    } 
    else { $true }
} 

function Get-RemoteFiles {
    param (
        [parameter(Mandatory = $true)][string]$jsonFile,
        [parameter(Mandatory = $true)][string]$targetDir
    )
    
    Write-Host "Starting downloading of files from '$jsonFile'..."

    Get-Content $jsonFile | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object {
    
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
function Get-Releases {
    param (
        [parameter(Mandatory = $true)][string]$jsonFile,
        [parameter(Mandatory = $true)][string]$targetDir
    )

    Write-Host "Starting downloading of GitHub release files from '$jsonFile'..."
    
    Get-Content $jsonFile | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object {

        $repo = $_.repo
        $releases = "https://api.github.com/repos/$repo/releases"
        $tag = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)[0].tag_name
    
        $file = $_.file
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

function Add-Rom {
    param(
        [String]$zipFile,
        [string]$targetFolder
    )
    if (Test-Path $zipFile) {
        # Create target directory
        New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
        if ( $zipFile.EndsWith("zip") -or $zipFile.EndsWith("7z") -or $zipFile.EndsWith("gz") ) {
            Expand-PackedFile $zipFile $targetFolder
        }
        else {
            Move-Item -Path $zipFile -Destination $targetFolder -Force | Out-Null
        }

    }
    else {
        Write-Host "ERROR: $zipFile not found."
        exit -1
    }
}

function Expand-PackedFile {
    param (
        [String]$archiveFile,
        [String]$targetFolder,
        [string]$zipFolderToCopy
    )
    # System Setup
    if (Test-Path $archiveFile) {
        # Create target directory
        New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
        # Extract to a temp folder
        $tempFolder = "$requirementsFolder/temp/"
        Extract -Path $archiveFile -Destination $tempFolder | Out-Null
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
        Write-Host "ERROR: $archiveFile not found."
        exit -1
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
    if (-Not [String]::IsNullOrEmpty($WorkingDir)) {
        $link.WorkingDirectory = $WorkingDir
    }
    if (-Not [String]::IsNullOrEmpty($ShortcutIcon)) {
        $link.IconLocation = $ShortcutIcon
    }
    $link.Save() 
}