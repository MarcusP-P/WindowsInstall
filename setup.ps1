#Requires -RunAsAdministrator

# You will need to set the execution policy for scripts
# for me: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# You may also need to run Unblock-File against this script

param 
(
    [string] $ConfigFile
)

# The buildnumber of this version of Windows
$WindowsVersion=[long]::Parse((Get-WmiObject Win32_OperatingSystem).BuildNumber)

# Known Build Numbers
$windows2004=19041
$windows1909=18363
$windows1903=18362
$windows1809=17763
$windows1803=17134
$windows1709=16299
$windows1703=15063

$tempFile=$env:TEMP + "\Status.json"


if ($windowsVersion -lt $windows1703)
{
	Write-Output "Winget only supports Windows 10 1703 or later. Because this script pretty much requires Winget, it will not run on an older version"
	exit
}

### Load the Configuration File
function Get-Configuration
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName
    )
    
    if (!(Test-Path $fileName -PathType leaf))
    {
        Write-Error "Could not find configuration file $fileName" -ErrorAction Stop
    }

    $ConfigurationObject= Get-Content -Raw -Path $fileName -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

    return $ConfigurationObject
}

### Functions for an empty status status file, settign the stage to 0

# Read the status file, creating it if needed
function Get-StatusFile
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName
    )

    if (!(Test-Path $fileName -PathType leaf))
    {
        $status=@{Stage=0;ConfigFile=""}

        Write-Host "FOO"

        Write-Host $status.

        # Save the new status
        Save-StatusFile -FileName $fileName -Status $status
        return $status
    }

    $status= Get-Content -Raw -Path $fileName | ConvertFrom-Json

    return $status
}

# Save the status file
function Save-StatusFile
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName,
        [Parameter (Mandatory)]
        [object]$status
    )
    $status | ConvertTo-Json | Out-File $fileName

}

### Status stages
# Get the stage from the status file
function Get-StatusStage
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName
    )

    $status = Get-StatusFile $fileName

    return $status.Stage

}

# Update the stage in the status file
function Set-StatusStage
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName,
        [Parameter (Mandatory)]
        [int]$stage
    )

    $status = Get-StatusFile -fileName $fileName

    $status.Stage=$stage

    Save-StatusFile -fileName $fileName -status $status
}

### Status config files
# Get the configuration file
function Get-StatusConfigFile
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName
    )

    $status = Get-StatusFile $fileName

    return $status.ConfigFile

}

# Update the stage in the status file
function Set-StatusConfigFile
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName,
        [Parameter (Mandatory)]
        [string]$configFilename
    )

    $status = Get-StatusFile -fileName $fileName

    $status.ConfigFile=$configFilename

    Save-StatusFile -fileName $fileName -status $status
}

### Functions to perform actions

# Windows store updates
function Update-StoreApps
{
	Write-Output "Upgrade all Windows Store apps. Please remember to log into the Windows Store when it opens."
    Read-Host -Prompt "Press Enter to start updating apps"
    Start-Process "ms-windows-store://downloadsandupdates"
    Read-Host -Prompt "Press Enter once the apps are updated"

}

# Install a windows store app
function Install-StoreApp
{
    param
    (
        [Parameter (Mandatory)]
        [string]$ProductId
    )
    # When winget supports Windows Store, update this
    Start-Process "ms-windows-store://pdp/?productId=$ProductID"
    Read-Host -Prompt "Press Enter once the package is installed"
}

# Install a winget package
function Install-WingetPackage
{
    param
    (
        [Parameter (Mandatory)]
        [string] $Id,
        [string[]] $AdditionalOptions
    )
    Write-Output "Installing $Id..."
    winget install --exact $Id $AdditionalOptions


}

# Download and install an installer
function Install-DownloadedFile
{
    param
    (
        [Parameter (Mandatory)]
        [string] $Url,
        [string] $WaitMessage,
        [string[]] $AdditionalOptions
    )

    $fileName=[System.IO.Path]::GetFileName($url)

    $filePath=$env:TEMP + "\" + $fileName

    Write-Output "Downloading $wsl2_kernel"

    Invoke-WebRequest -Uri $Url -OutFile "$filePath"

    if (!$AdditionalOptions)
    {
        Start-Process "$filePath" -Wait
    }
    else
    {
        Start-Process "$filePath" -ArgumentList $AdditionalOptions -Wait
    }

    if ($WaitMessage)
    {
    	Read-Host -Prompt "$WaitMessage"
    }

    Remove-Item -Path "$filePath"
}


# Create an Office Deployment Tool XML File
function Create-OfficeDeploymentConfigurationFile
{
    param
    (
         [Parameter (Mandatory)]
         [string] $FileName
    )

    echo "Creating Office Configuration file: $FileName"

    [xml]$ConfigurationFile=New-Object xml

    $Configuration=$ConfigurationFile.CreateElement("Configuration")
    $Add=$ConfigurationFile.CreateElement("Add")

    $Configuration.AppendChild($Add) | Out-Null

    $ConfigurationFile.AppendChild($Configuration) | Out-Null

    $ConfigurationFile.Save($FileName)   
}

# Add Attributes to Add
function Add-OfficeConfigurationAttributesToAdd
{
    param
    (
         [Parameter (Mandatory)]
         [string] $FileName,
         [Parameter (Mandatory)]
         [string] $Attribute,
         [Parameter (Mandatory)]
         [string] $Value
    )

    echo "Adding configuration attribute $Attribute=$Value"

    [xml]$ConfigurationFile=New-Object xml
    $ConfigurationFile.PreserveWhitespace=$true
    $ConfigurationFile.Load($FileName)

    # We only assume one Add element.
    $Add=$ConfigurationFile.SelectSingleNode("/Configuration/Add[1]")
    $NewAttribute=$ConfigurationFile.CreateAttribute($Attribute)
    $NewAttribute.Value = $Value

    $Add.Attributes.Append($NewAttribute) | Out-Null

    $ConfigurationFile.Save($FileName)
}
        
# Add Office Products
function Add-OfficeProduct
{
    param
    (
         [Parameter (Mandatory)]
         [string] $FileName,
         [Parameter (Mandatory)]
         [string] $ProductID
    )

    echo "Adding Product $ProductID"
    [xml]$ConfigurationFile=New-Object xml
    $ConfigurationFile.PreserveWhitespace=$true
    $ConfigurationFile.Load($FileName)

    # We only assume one Add element.
    $Add=$ConfigurationFile.SelectSingleNode("/Configuration/Add[1]")

    $Product=$ConfigurationFile.CreateElement("Product")

    $ProductIdAttribute=$ConfigurationFile.CreateAttribute("ID")
    $ProductIdAttribute.Value=$ProductID

    $Product.Attributes.Append($ProductIdAttribute) | Out-Null
    $Add.AppendChild($Product) | Out-Null

    $ConfigurationFile.Save($FileName)

}

# Add a language to a produxt
function Add-OfficeProductLangage
{
    param
    (
         [Parameter (Mandatory)]
         [string] $FileName,
         [Parameter (Mandatory)]
         [string] $ProductID,
         [Parameter (Mandatory)]
         [string] $LanguageID
    )

    echo "Adding Product $ProductID Language: $LanguageID"

    [xml]$ConfigurationFile=New-Object xml
    $ConfigurationFile.PreserveWhitespace=$true
    $ConfigurationFile.Load($FileName)

    # We only assume one Add element.
    $Product=$ConfigurationFile.SelectSingleNode("/Configuration/Add/Product[@ID='$ProductID']")

    $Language=$ConfigurationFile.CreateElement("Language")

    $LanguageIdAttribute=$ConfigurationFile.CreateAttribute("ID")
    $LanguageIdAttribute.Value=$LanguageID

    $Language.Attributes.Append($LanguageIdAttribute) | Out-Null


    $Product.AppendChild($Language) | Out-Null


    $ConfigurationFile.Save($FileName)
}

function Add-OfficeProductLanguageAttribute
{
    param
    (
         [Parameter (Mandatory)]
         [string] $FileName,
         [Parameter (Mandatory)]
         [string] $ProductID,
         [Parameter (Mandatory)]
         [string] $LanguageID,
         [Parameter (Mandatory)]
         [string] $Attribute,
         [Parameter (Mandatory)]
         [string] $Value
    )

    echo "Adding Product $ProductID Language: $LanguageID Attribute $Attribute=$Value"

    [xml]$ConfigurationFile=New-Object xml
    $ConfigurationFile.PreserveWhitespace=$true
    $ConfigurationFile.Load($FileName)

    # We only assume one Add element.
    $Language=$ConfigurationFile.SelectSingleNode("/Configuration/Add/Product[@ID='$ProductID']/Language[@ID='$LanguageID']")

    $LanguageIdAttribute=$ConfigurationFile.CreateAttribute("$Attribute")
    $LanguageIdAttribute.Value=$Value

    $Language.Attributes.Append($LanguageIdAttribute) | Out-Null

    $ConfigurationFile.Save($FileName)
}

# Add a language to a produxt
function Add-OfficeProductDisplay
{
    param
    (
         [Parameter (Mandatory)]
         [string] $FileName,
         [Parameter (Mandatory)]
         [string] $ProductID
    )

    echo "Adding Product $ProductID Display Element"

    [xml]$ConfigurationFile=New-Object xml
    $ConfigurationFile.PreserveWhitespace=$true
    $ConfigurationFile.Load($FileName)

    # We only assume one Add element.
    $Product=$ConfigurationFile.SelectSingleNode("/Configuration/Add/Product[@ID='$ProductID']")

    $Display=$ConfigurationFile.CreateElement("Display")

    $Product.AppendChild($Display) | Out-Null


    $ConfigurationFile.Save($FileName)
}

function Add-OfficeProductDisplayAttribute
{
    param
    (
         [Parameter (Mandatory)]
         [string] $FileName,
         [Parameter (Mandatory)]
         [string] $ProductID,
         [Parameter (Mandatory)]
         [string] $Attribute,
         [Parameter (Mandatory)]
         [string] $Value
    )

    echo "Adding Product $ProductID Display Attribute $Attribute=$Value"

    [xml]$ConfigurationFile=New-Object xml
    $ConfigurationFile.PreserveWhitespace=$true
    $ConfigurationFile.Load($FileName)

    # We only assume one Add element, and one Display Element per Product
    $Display=$ConfigurationFile.SelectSingleNode("/Configuration/Add/Product[@ID='$ProductID']/Display[1]")

    $DisplayIdAttribute=$ConfigurationFile.CreateAttribute("$Attribute")
    $DisplayIdAttribute.Value=$Value

    $Display.Attributes.Append($DisplayIdAttribute) | Out-Null

    $ConfigurationFile.Save($FileName)
}

function Add-OfficeProductExcludeApp
{
    param
    (
         [Parameter (Mandatory)]
         [string] $FileName,
         [Parameter (Mandatory)]
         [string] $ProductID,
         [Parameter (Mandatory)]
         [string] $ExcludeAppID
    )

    echo "Adding Product $ProductID ExcludeApp $ExcludeAppID"

    [xml]$ConfigurationFile=New-Object xml
    $ConfigurationFile.PreserveWhitespace=$true
    $ConfigurationFile.Load($FileName)

    # We only assume one Add element.
    $Product=$ConfigurationFile.SelectSingleNode("/Configuration/Add/Product[@ID='$ProductID']")

    $ExcludeApp=$ConfigurationFile.CreateElement("ExcludeApp")

    $ExcludeIdAttribute=$ConfigurationFile.CreateAttribute("ID")
    $ExcludeIdAttribute.Value=$ExcludeAppID

    $ExcludeApp.Attributes.Append($ExcludeIdAttribute) | Out-Null


    $Product.AppendChild($ExcludeApp) | Out-Null


    $ConfigurationFile.Save($FileName)

}

##### Start of commands...

### Make sure the config file exists and is setup
# We only watn the user to pass the config filename on the command line
if ((Get-StatusStage -fileName $tempFile) -eq 0)
{
    if (! $ConfigFile)
    {
        Write-Error "Configuration file not specified" -ErrorAction Stop
    }

    if (!(Test-Path $ConfigFile -PathType leaf))
    {
        Write-Error "Could not find configuration file $ConfigFile" -ErrorAction Stop
    }

    $ConfigFile = Resolve-Path $ConfigFile

    Set-StatusConfigFile -fileName $tempFile -configFilename $ConfigFile
}
else
{
    if ($ConfigFile)
    {
        Write-Error "Configuration file shoudl not be passed" -ErrorAction Stop
    }

    $ConfigFile = Get-StatusConfigFile -fileName $tempFile

    if (!(Test-Path $ConfigFile -PathType leaf))
    {
        Write-Error "Could not find configuration file $ConfigFile" -ErrorAction Stop
    }
}

$Config = Get-Configuration -fileName $ConfigFile



if ((Get-StatusStage -fileName $tempFile) -eq 0)
{
    $NeedsReboot=$false
    if ($Config.ComputerName)
    {
        $Result = Rename-computer -NewName $Config.ComputerName -Force -PassThru -ErrorAction Stop
        if ($Result.HasSucceeded -eq $true)
        {
            $NeedsReboot = $True
        }
    }

    if ($Config.InstallWsl)
    {
        if ($Config.InstallWsl -eq $true)
        {
            $Result = Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online  -All -NoRestart
            if ($Result.RestartNeeded -eq $true)
            {
                $NeedsReboot = $True
            }

            $Result = Enable-WindowsOptionalFeature -FeatureName VirtualMachinePlatform -Online  -All -NoRestart
            if ($Result.RestartNeeded -eq $true)
            {
                $NeedsReboot = $True
            }
        }
    }
    Set-StatusStage -fileName $tempFile	-stage 1

    if ($NeedsReboot -eq $true)
    {
	    Read-Host -Prompt "Press Enter to reboot"

        shutdown /r /f /t 0

        exit
    }
}

if ((Get-StatusStage -fileName $tempFile) -eq 1)
{
	start ms-settings:windowsupdate-action
	
    Set-StatusStage -fileName $tempFile	-stage 2

	Write-Output "Please install any windows updates. If you do not need to reboot this device, re-run this script"
	
    exit
}

if ($Config.InstallWsl)
{
    if ($Config.InstallWsl -eq $true)
    {
        # WSL2 is only supported on Windows 2004 and later
        # Since creating this, WSL 2 has been backported to Windows 10 1903, but I can't be bothered setting up the
        # checks because I don't intend to run older versions of Windows. Feel free to file a PR
        if ($windowsVersion -ge $windows2004)
        {

            # the WSL kernel needs to be downlaoded manually for now.
            # see https://aka.ms/wsl2kernel

            Install-DownloadedFile -Url "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -AdditionalOptions ("/quiet")

            # Set the wsl default version before we begin
            wsl --set-default-version 2
        }
    }
}

# Windows store updates page
Update-StoreApps

# Install winget
Install-StoreApp -ProductId 9NBLGGH4NNS1

Install-WingetPackage -Id OpenJS.Nodejs
Install-WingetPackage -Id Microsoft.VisualStudio.Enterprise -AdditionalOptions ("--override", "--passive --wait --norestart --add Microsoft.VisualStudio.Workload.CoreEditor --add Microsoft.VisualStudio.Workload.NetWeb;installOptional --add Microsoft.VisualStudio.Workload.Node --add Microsoft.VisualStudio.Workload.ManagedDesktop;includeOptional --add Microsoft.VisualStudio.Workload.NetCoreTools;includeRecommended --add Microsoft.VisualStudio.Workload.Office;includeOptional --add Microsoft.VisualStudio.Component.LinqToSql --add Microsoft.NetCore.ComponentGroup.DevelopmentTools.2.1 --add Microsoft.NetCore.ComponentGroup.Web.2.1")
Install-WingetPackage -Id Microsoft.VisualStudioCode

# Install 1Password
Install-WingetPackage -Id Microsoft.Edge
Install-WingetPackage -Id AgileBits.1Password
Install-WingetPackage -Id Microsoft.PowerShell
Install-WingetPackage -Id Microsoft.PowerToys

Install-StoreApp -ProductId 9N0DX20HK701

Install-WingetPackage -Id Notepad++.Notepad++
Install-WingetPackage -Id Git.Git
Install-WingetPackage -Id PuTTY.PuTTY
Install-WingetPackage -Id TortoiseGit.TortoiseGit
Install-WingetPackage -Id vim.vim
Install-WingetPackage -Id 7zip.7zip

Install-WingetPackage -Id SQLiteBrowser.SQLiteBrowser
Install-WingetPackage -Id Microsoft.AzureDataStudio

Install-WingetPackage -Id VMware.WorkstationPro

# Install Store stuff that comes with the surface
# Surface App
Install-StoreApp -ProductId 9WZDNCRFJB8P

# Whiteboard
Install-StoreApp -ProductId 9MSPC6MP8FM4

# MPEG2 Video Extensions
Install-StoreApp -ProductId 9N95Q1ZZPMH4

# HEVC Video Extensions
Install-StoreApp -ProductId 9NMZLZ57R3T7

#Install-WingetPackage -Id Canonical.Ubuntu
Install-StoreApp -ProductId 9NBLGGH4MSV6

# Setup the distro
ubuntu

# Fork git client
Install-DownloadedFile -Url https://git-fork.com/update/win/ForkInstaller.exe -WaitMessage "Press Enter once Fork has finished installing"

# Office365

#https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_12827-20268.exe

$Office365_Deployment=$env:TEMP + "\officedeploymenttool_12827-20268.exe"
$Office365_Extract=$env:TEMP + "\officedeploymenttool_12827-20268"
$Office365_Tool=$Office365_Extract + "\setup.exe"
$Office365_Config_File_Name="Office.xml"
$Office365_Config_File=$Office365_Extract + "\" +$Office365_Config_File_Name

# Download and extract the Office Deployment tool
Install-DownloadedFile -Url "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_12827-20268.exe" -AdditionalOptions ("/extract:""$Office365_Extract""","/quiet")

# Create the config file
Create-OfficeDeploymentConfigurationFile -fileName $Office365_Config_File
Add-OfficeConfigurationAttributesToAdd -Attribute OfficeClientEdition -value 64 -FileName $Office365_Config_File
Add-OfficeConfigurationAttributesToAdd -Attribute MigrateArch -value True -FileName $Office365_Config_File
Add-OfficeConfigurationAttributesToAdd -Attribute OfficeMgmtCOM -value False -FileName $Office365_Config_File

Add-OfficeProduct -ProductID O365HomePremRetail -FileName $Office365_Config_File
Add-OfficeProductLangage -ProductID O365HomePremRetail -LanguageID MatchOS -FileName $Office365_Config_File
Add-OfficeProductLanguageAttribute -ProductID O365HomePremRetail -LanguageID MatchOS -Attribute Fallback -Value en-us -FileName $Office365_Config_File
Add-OfficeProductDisplay -ProductID O365HomePremRetail -FileName $Office365_Config_File
Add-OfficeProductDisplayAttribute -ProductID O365HomePremRetail -Attribute Level -Value Full -FileName $Office365_Config_File
Add-OfficeProductExcludeApp -ProductID O365HomePremRetail -ExcludeAppID Access -FileName $Office365_Config_File
Add-OfficeProductExcludeApp -ProductID O365HomePremRetail -ExcludeAppID OneNote -FileName $Office365_Config_File
Add-OfficeProductExcludeApp -ProductID O365HomePremRetail -ExcludeAppID OneDrive -FileName $Office365_Config_File
Add-OfficeProductExcludeApp -ProductID O365HomePremRetail -ExcludeAppID Outlook -FileName $Office365_Config_File
Add-OfficeProductExcludeApp -ProductID O365HomePremRetail -ExcludeAppID Publisher -FileName $Office365_Config_File

Add-OfficeProduct -ProductID VisioPro2019Retail -FileName $Office365_Config_File
Add-OfficeProductLangage -ProductID VisioPro2019Retail -LanguageID MatchOS -FileName $Office365_Config_File
Add-OfficeProductLanguageAttribute -ProductID VisioPro2019Retail -LanguageID MatchOS -Attribute Fallback -Value en-us -FileName $Office365_Config_File
Add-OfficeProductDisplay -ProductID VisioPro2019Retail -FileName $Office365_Config_File
Add-OfficeProductDisplayAttribute -ProductID VisioPro2019Retail -Attribute Level -Value Full -FileName $Office365_Config_File

Add-OfficeProduct -ProductID ProjectPro2019Retail -FileName $Office365_Config_File
Add-OfficeProductLangage -ProductID ProjectPro2019Retail -LanguageID MatchOS -FileName $Office365_Config_File
Add-OfficeProductLanguageAttribute -ProductID ProjectPro2019Retail -LanguageID MatchOS -Attribute Fallback -Value en-us -FileName $Office365_Config_File
Add-OfficeProductDisplay -ProductID ProjectPro2019Retail -FileName $Office365_Config_File
Add-OfficeProductDisplayAttribute -ProductID ProjectPro2019Retail -Attribute Level -Value Full -FileName $Office365_Config_File

Write-Output "Installing Office 365"
Start-Process "$Office365_Tool" -ArgumentList "/configure ""$Office365_Config_File""" -Wait

Remove-Item -Path "$Office365_Extract" -Recurse
