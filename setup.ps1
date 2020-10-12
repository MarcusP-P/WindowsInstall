#Requires -RunAsAdministrator


# You will need to set the execution policy for scripts
# for me: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# You may also need to run Unblock-File against this script

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

if ($windowsVersion -lt $windows1703)
{
	Write-Output "Winget only supports Windows 10 1703 or later. Because this script pretty much requires Winget, it will not run on an older version"
	exit
}

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

$tempFile=$env:TEMP + "\updateStatus"

if (!(Test-Path $tempFile -PathType leaf))
{
    Rename-computer -NewName "Marcus-Surface" -Force
    Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online  -All -NoRestart
    Enable-WindowsOptionalFeature -FeatureName VirtualMachinePlatform -Online  -All -NoRestart
	
    $null > $tempFile

	Read-Host -Prompt "Press Enter to reboot"

    shutdown /r /f /t 0

    exit
}

$tempFile2=$env:TEMP + "\updateStatus2"

if (!(Test-Path $tempFile2 -PathType leaf))
{
	start ms-settings:windowsupdate-action
	
    $null > $tempFile2

	Write-Output "Please install any windows updates. If you do not need to reboot this device, re-run this script"
	
    exit
}

# WSL2 is only supported on Windows 2004 and later
if ($windowsVersion -ge $windows2004)
{

    # the WSL kernel needs to be downlaoded manually for now.
    # see https://aka.ms/wsl2kernel

    $wsl2_kernel=$env:TEMP + "\wsl_update_x64.msi"

    Write-Output "Downloading WSL kernel $wsl2_kernel"

    Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile "$wsl2_kernel"

    Start-Process "$wsl2_kernel" -ArgumentList '/quiet' -Wait

    Remove-Item -Path "$wsl2_kernel"

    # Set the wsl default version before we begin
    wsl --set-default-version 2
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
$fork_Installer=$env:TEMP + "\ForkInstaller.exe"
Write-Output "Downloading Fork Installer $fork_Installer"
Invoke-WebRequest -Uri "https://git-fork.com/update/win/ForkInstaller.exe" -OutFile "$fork_Installer"

Start-Process "$fork_Installer" -Wait

Read-Host -Prompt "Press Enter once Fork has finished installing"

Remove-Item -Path "$fork_Installer"

# Office365

#https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_12827-20268.exe

$Office365_Deployment=$env:TEMP + "\officedeploymenttool_12827-20268.exe"
$Office365_Extract=$env:TEMP + "\officedeploymenttool_12827-20268"
$Office365_Tool=$Office365_Extract + "\setup.exe"
$Office365_Config_File_Name="Office.xml"
$Office365_Config_File=$Office365_Extract + "\" +$Office365_Config_File_Name

$Office365_Config_Contents=@'
<Configuration>
  <Add OfficeClientEdition="64" MigrateArch="True" OfficeMgmtCOM="False">
    <Product ID="O365HomePremRetail">
      <Language ID="MatchOS" Fallback="en-us" />
	  <Display Level="Full" AcceptEULA="FALSE" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="Outlook" />
      <ExcludeApp ID="Publisher" />
    </Product>
    <Product ID="VisioPro2019Retail">
      <Language ID="en-us" />
    </Product>
    <Product ID="ProjectPro2019Retail">
      <Language ID="en-us" />
    </Product>
  </Add>
</Configuration>
'@

Write-Output "Downloading Office deployment tool $Office365_Deployment"
Invoke-WebRequest -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_12827-20268.exe" -OutFile "$Office365_Deployment"

Write-Output "Extract Office365 Deploymeny Tool"
Start-Process "$Office365_Deployment" -ArgumentList "/extract:""$Office365_Extract"" /quiet" -Wait

Remove-Item -Path "$Office365_Deployment"

# Create the config file

Write-Output "Creating Office365 config file"
New-Item -Path "$Office365_Extract\" -Name "$Office365_Config_File_Name" -ItemType "file" -Value "$Office365_Config_Contents" | Out-Null

Write-Output "Installing Office 365"
Start-Process "$Office365_Tool" -ArgumentList "/configure ""$Office365_Config_File""" -Wait

Remove-Item -Path "$Office365_Extract" -Recurse
