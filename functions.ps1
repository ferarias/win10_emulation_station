using namespace System.IO

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

Function Get-RemoteFiles {
    param (
        [parameter(Mandatory = $true)][string]$jsonFile,
        [parameter(Mandatory = $true)][string]$targetDir
    )
    
    Get-Content $jsonFile | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object {
    
        $file = $_.file
        $url = $_.url
        $repo = $_.repo
        if($Null -ne $repo) {
            # This is a GitHub repo. We need to find out the latest tag and then build the URI to that release file
            $releases = "https://api.github.com/repos/$repo/releases"
            $tag = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)[0].tag_name
            $url = "https://github.com/$repo/releases/download/$tag/$file"
            $name = $file.Split(".")[0]
            $zip = "$name-$tag.zip"
            $output = "$targetDir\$zip"
        } else {
            $output = "$targetDir\$file"
        }
        if (![System.IO.File]::Exists($output)) {
    
            Write-Host -ForegroundColor Green "Downloading $file"
            Invoke-WebRequest $url -Out $output   
        }
        else {
            Write-Host -ForegroundColor Gray "Already downloaded $file... skipped."
        }
    }
}

Function Expand-PackedFile {
    param (
        [String]$archiveFile,
        [String]$targetFolder,
        [string]$zipFolderToCopy
    )
    $tempFolder = New-TemporaryDirectory
    try {
        if (Test-Path $archiveFile) {
            # Create target directory
            New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
            # Extract to a temp folder
            Extract -Path $archiveFile -Destination $tempFolder | Out-Null
            # Move files to the final directory in systems folder
            if ($zipFolderToCopy -eq "") {
                Robocopy.exe $tempFolder $targetFolder /E /NFL /NDL /NJH /NJS /nc /ns /np /MOVE | Out-Null
            }
            else {
                Robocopy.exe $tempFolder/$zipFolderToCopy $targetFolder /E /NFL /NDL /NJH /NJS /nc /ns /np /MOVE | Out-Null
            }
        }
        else {
            Write-Host -ForegroundColor Red "ERROR: $archiveFile not found."
            exit -1
        }
    }
    finally {
        if(Test-Path $tempFolder) {
            Remove-Item $tempFolder -Force -Recurse | Out-Null
        }
    }
    
}

Function Extract([string]$Path, [string]$Destination) {
    $sevenZipApplication = "$cacheFolder\7z\7z.exe"
    $sevenZipArguments = @(
        'x'                     ## eXtract files with full paths
        '-y'                    ## assume Yes on all queries
        "`"-o$($Destination)`"" ## set Output directory
        "`"$($Path)`""          ## <archive_name>
    )
    & $sevenZipApplication $sevenZipArguments | Out-Null
}

Function Write-ESSystemsConfig {
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

Function Add-Shortcut {
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

Function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}