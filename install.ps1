param (
    [string]$nvmhome,
    [string]$nvmlink
)

$nvmVersion = "1.5.5"
$nvmVersionV = "v$nvmVersion"
$DisableInstallNvmFromTgz = $false

$NVM_ZIP_URL = "https://github.com/jchip/nvm/archive/$nvmVersionV.zip"
$NVM_TGZ_URL = "https://registry.npmjs.org/@jchip/nvm/-/nvm-$nvmVersion.tgz"

$ProgressPreference = "SilentlyContinue"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Find-Folders {
    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $browse = New-Object System.Windows.Forms.FolderBrowserDialog
    $browse.SelectedPath = "$Env:HOMEDRIVE$Env:HOMEPATH"
    $browse.ShowNewFolderButton = $false
    $browse.Description = "Select or create a directory for NVM HOME"

    $loop = $true
    while ($loop) {
        if ($browse.ShowDialog() -eq "OK") {
            $loop = $false

            #Insert your script here
            return $browse.SelectedPath
        }
        else {
            $res = [System.Windows.Forms.MessageBox]::Show("You clicked Cancel. Would you like to try again or exit?", "Select a location", [System.Windows.Forms.MessageBoxButtons]::RetryCancel)
            if ($res -eq "Cancel") {
                #Ends script
                exit
            }
        }
    }
    $browse.SelectedPath
    $browse.Dispose()
}


function getLtsVersion() {
    $nodejsOrg = "https://nodejs.org"
    $nodejsHtml = "$Env:TMP\nodejs.html"
    $foundVersion = "v12.13.0"

    Try {
        Invoke-WebRequest $nodejsOrg -OutFile $nodejsHtml
        $M = Select-String -CaseSensitive -Path $nodejsHtml -Pattern '(\d+\.\d+\.\d+)(?= LTS)'

        $G = $M.Matches.Groups[1]
        if ($G.Success) {
            $v = $G.Value
            if (-not ($v.StartsWith("v"))) {
                $v = "v" + $v
            }
            $foundVersion = $v
        }
    }
    Catch {
    }

    return $foundVersion
}

$DefaultNodeVersion = getLtsVersion

function Get-NodeJS($version) {
    Try {
        if ( -not (Test-Path $NVM_NODE )) {
            New-Item -Path "$NVM_NODE" -ItemType "directory" | Out-Null
        }

        if ( Test-Path Env:NVM_NODEJS_ORG_MIRROR ) {
            $nodejsMirror = $Env:NVM_NODEJS_ORG_MIRROR
            Write-Output "Using Env:NVM_NODEJS_ORG_MIRROR $nodejsMirror"
        }
        else {
            $nodejsMirror = "https://nodejs.org/dist"
        }

        if ([System.Environment]::Is64BitOperatingSystem) {
            $arch = "x64"
        }
        else {
            $arch = "x86"
        }

        $zipFile = "node-$version-win-$arch.zip"
        $nodejsBinUrl = "$nodejsMirror/$version/$zipFile"
        $cacheDir = "$NVM_CACHE\$version"
        if ( -not (Test-Path $cacheDir)) {
            New-Item -Path "$cacheDir" -ItemType "directory" | Out-Null
        }
        $destZipFile = "$cacheDir\node.zip"

        if ( -not (Test-Path "$destZipFile")) {
            Write-Output "Retrieving $nodejsBinUrl"
            Invoke-WebRequest $nodejsBinUrl -OutFile $destZipFile
        }

        Add-Type -Assembly System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($destZipFile)
        $zip.Entries | Where-Object { $_.Name -like 'node.exe' } |
        ForEach-Object { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$NVM_NODE_EXE", $true) }
        $zip.Dispose()

        # Expand-Archive "$destZipFile" $NVM_HOME\node
        # Remove-Item "$destZipFile"
    }
    Catch {
        Write-Error -Message "Retrieving node version $version binary failed  $_.Exception.Message"
        exit
    }
}

Try {
    $RegPath = Get-ItemPropertyValue -Path "HKCU:\Environment" -Name Path
}
Catch {
    $RegPath = ""
}

function Compare-Path {
    <#
      .SYNOPSIS
        Compare a Directory against the Current Path
      .DESCRIPTION
        Compare directories to the current path and return array
        of the ones that are new.
      .EXAMPLE
        Compare-Path -Directory "C:\Program Files\Notepad++"
      .PARAMETER Directory
        The name of the directory to compare to the current path.
    #>

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $True,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = 'What directory would you like to add?')]
        [Alias('dir')]
        [string[]]$Directory,
        [string[]]$Path = $Env:PATH
    )

    PROCESS {
        $Path = $Path.Split(';')
        $Path = $Path.Where( { $_ -ne "" })
        $dirsToAdd = @()

        foreach ($dir in $Directory) {
            if (($Path -contains $dir) -or ($dirsToAdd -contains $dir)) {
                Write-Verbose "$dir is already present in PATH"
            }
            else {
                $dirsToAdd += $dir
            }
        }

        return $dirsToAdd
    }
}

if ( $nvmhome -ne "" ) {
    $NVM_HOME = $nvmhome
    Write-Output "Got NVM_HOME $NVM_HOME from command line"
}
elseif ( Test-Path Env:NVM_HOME ) {
    $NVM_HOME = $Env:NVM_HOME
    Write-Output "Got NVM_HOME $NVM_HOME from Env"
}
else {
    $NVM_HOME = Find-Folders "$Env:USERPROFILE"
    Write-Output "Selected folder for NVM_HOME $NVM_HOME"
}

$NVM_CACHE = "$NVM_HOME\cache"
$NVM_NODE = "$NVM_HOME\nodejs"
$NVM_BIN = "$NVM_HOME\bin"
$NVM_NODE_EXE = "$NVM_HOME\node.exe"

if ( $nvmlink -ne "" ) {
    $NVM_LINK = $nvmlink
    Write-Output "Got NVM_LINK $NVM_LINK from command line"
}
elseif ( Test-Path Env:NVM_LINK ) {
    $NVM_LINK = $Env:NVM_LINK
    Write-Output "Got NVM_LINK $NVM_LINK from Env"
}
else {
    $NVM_LINK = "$NVM_NODE\bin"
    Write-Output "Default NVM_LINK to $NVM_LINK"
}

Try {
    $existNodejsVersion = & $NVM_NODE_EXE -v
}
Catch {
    $existNodejsVersion = "bad"
}

if ( -not ($DefaultNodeVersion -eq $existNodejsVersion) ) {
    Get-NodeJS $DefaultNodeVersion
}

function Add-UserPath ($dirsToAdd) {
    if (($null -ne $dirsToAdd) -and ($dirsToAdd.count -gt 0)) {
        # Update user's path in registry
        $newRegPath = [String]::Join(";", ($RegPath.split(";") + $dirsToAdd).Where( { $_ -ne "" }))
        New-ItemProperty -Path "HKCU:\Environment" -Name "Path" -Value "$newRegPath" -Force | Out-Null
    }
}

$dirsToAdd = Compare-Path -Directory @( "$NVM_BIN", "$NVM_LINK" ) -Path $Env:Path
$Env:Path = [String]::Join(";", ($Env:Path.Split(";") + $dirsToAdd).Where( { $_ -ne "" }))

$userDirsToAdd = Compare-Path -Directory @( "$NVM_BIN", "$NVM_LINK" ) -Path $RegPath
Add-UserPath $userDirsToAdd

$Env:NVM_LINK = "$NVM_LINK"
$Env:NVM_HOME = $NVM_HOME
New-ItemProperty -Path "HKCU:\Environment" -Name "NVM_HOME" -Value "$NVM_HOME" -Force | Out-Null
# use setx once so it broadcasts WM_SETTINGCHANGE message
setx.exe NVM_LINK "$NVM_LINK" | Out-Null

function installNvmFromZip() {
    $nvmZipUrl = $NVM_ZIP_URL

    if ( -not (Test-Path $NVM_CACHE)) {
        New-Item -Path "$NVM_CACHE" -ItemType "directory" | Out-Null
    }

    $nvmDestZipFile = "$NVM_CACHE\nvm-$nvmVersionV.zip"

    Write-Output "Retrieving $nvmZipUrl"
    Invoke-WebRequest $nvmZipUrl -OutFile $nvmDestZipFile

    $installFiles = @( "bin", "dist", "package.json" )

    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($nvmDestZipFile)
    $zip.Entries |
    ForEach-Object {
        $f = $_.FullName.split("/")
        $f = $f[1..($f.count - 1)]
        $name = [String]::Join("\", $f)
        if ( $installFiles -contains $f[0] ) {

            $fullName = "$NVM_HOME\$name"
            if ( $_.Name -eq "" ) {
                if ( -not (Test-Path "$fullName")) {
                    New-Item -Path "$fullName" -ItemType "directory" | Out-Null
                }
            }
            else {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$fullName", $true)
            }
        }
    }
    $zip.Dispose()
}

function installNvmFromTgz() {
    $nvmTgzUrl = $NVM_TGZ_URL

    if ( -not (Test-Path $NVM_CACHE)) {
        New-Item -Path "$NVM_CACHE" -ItemType "directory" | Out-Null
    }

    $nvmDestTgzFile = "$NVM_CACHE\nvm-$nvmVersionV.tgz"

    Write-Output "Retrieving $nvmTgzUrl"
    Invoke-WebRequest $nvmTgzUrl -OutFile $nvmDestTgzFile

    & "$Env:SystemRoot\system32\tar.exe" -xf "$nvmDestTgzFile" -C "$NVM_HOME"
    Copy-Item "$NVM_HOME\package\*" "$NVM_HOME" -Force -Recurse
    Remove-Item "$NVM_HOME\package" -Recurse
}

if ( Test-Path $PSScriptRoot\test.ps1 ) {
    & $PSScriptRoot\test.ps1
}
else {
    ($tar = Get-Command "$Env:SystemRoot\system32\tar.exe" 2>&1) | Out-Null
    if ( ($tar.GetType().Name -eq "ErrorRecord") -or ($DisableInstallNvmFromTgz)) {
      installNvmFromZip
    }
    else {
        installNvmFromTgz
    }
}

& nvm.ps1 install $DefaultNodeVersion

if ( -not (Test-Path Env:\NVM_USE) ) {
    & nvm.ps1 use $DefaultNodeVersion
}

if ( -not (Test-Path $NVM_LINK)) {
    & nvm.ps1 link $DefaultNodeVersion
}

Write-Output "NVM installed, Node.js version $Env:NVM_USE activated."
