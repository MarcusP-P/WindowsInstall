#Requires -RunAsAdministrator

# TODO:
# * Start the store app to load the updates before we begin
# * Use one drop file to keep state, rather than one for every stage
# * Auto elevate to Admin
# * While doing rebooting, re-start script on login automatically
# * add uninstall of Windows Installer apps
# * Add Windows Store uninstaller
# * Use a configuration file to allow different configs fpr different computers
# * Do upgrades before WSL to allow for an update to a more recent version of Windows

# Install stuff, and configure stuff
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

$tempFile=$env:TEMP + "\updateStatus"

if (!(Test-Path $tempFile -PathType leaf))
{
    Rename-computer -NewName "Marcus-Surface" -Force
    Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online  -All -NoRestart
    Enable-WindowsOptionalFeature -FeatureName VirtualMachinePlatform -Online  -All -NoRestart
	
    $null > $tempFile

	Read-Host -Prompt "Press Enter to reboot..."

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

    echo "Downloading WSL kernel $wsl2_kernel"

    Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile "$wsl2_kernel"

    Start-Process $wsl2_kernel -ArgumentList '/quiet' -Wait

    del $wsl2_kernel

    # Set the wsl default version before we begin
    wsl --set-default-version 2
}

# Install winget
Start-Process "ms-windows-store://pdp/?productId=9NBLGGH4NNS1"
Read-Host -Prompt "Press Enter once the package is installed"

winget install --exact OpenJS.Nodejs
winget install --exact Microsoft.VisualStudio.Enterprise
winget install --exact Microsoft.VisualStudioCode

# Install 1Password
winget install --exact Microsoft.Edge
winget install --exact AgileBits.1Password
winget install --exact Microsoft.PowerShell
winget install --exact Microsoft.PowerToys

# When winget supports Windows Store, update this
#winget install --exact Microsoft.WindowsTerminal
Start-Process "ms-windows-store://pdp/?productId=9N0DX20HK701"
Read-Host -Prompt "Press Enter once the package is installed"

winget install --exact Notepad++.Notepad++
winget install --exact Git.Git
winget install --exact PuTTY.PuTTY
winget install --exact TortoiseGit.TortoiseGit
winget install --exact vim.vim
winget install --exact 7zip.7zip

winget install --exact SQLiteBrowser.SQLiteBrowser
winget install --exact Microsoft.AzureDataStudio

winget install --exact VMware.WorkstationPro

# The Winget version of Ubuntu is 18.x, so get this from the store
# When winget supports Windows Store, update this
#winget install --exact Canonical.Ubuntu
Start-Process "ms-windows-store://pdp/?productId=9NBLGGH4MSV6"
Read-Host -Prompt "Press Enter once the package is installed"

# Setup the distro
ubuntu