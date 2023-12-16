# Copyright (c) 2020, Marcus Pallinger

# You will need to set the execution policy for scripts
# for me: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# You may also need to run Unblock-File against this script

param 
(
    [string] $ConfigFile
)

# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) 
{
    try
    {
        $CommandLine = "-NoExit -Command Set-Location `"$PWD`"; `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.BoundParameters.Values + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
    catch
    {
        Write-Host "Could not elevate to administrator. Please re run this from an Admin Powershell"
        Exit
    }
}

# The buildnumber of this version of Windows
$WindowsVersion=[long]::Parse((Get-WmiObject Win32_OperatingSystem).BuildNumber)

# Known Build Numbers
$windows21H2=19044
$windows21H1=19043
$windows20H2=19042
$windows2004=19041
$windows1909=18363
$windows1903=18362
$windows1809=17763
$windows1803=17134
$windows1709=16299
$windows1703=15063

$tempFile=$env:TEMP + "\Status.json"

$startupFile=Join-Path -Path $([System.Environment]::GetFolderPath("Startup")) -ChildPath "WinstallStartup.cmd"

if ($windowsVersion -lt $windows1809)
{
	Write-Host "Winget only supports Windows 10 1809 or later. Because this script pretty much requires Winget, it will not run on an older version"
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
        $status=@{Stage="";ConfigFile="";TaskStage=0}

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
        [string]$stage
    )

    $status = Get-StatusFile -fileName $fileName

    $status.Stage=$stage

    Save-StatusFile -fileName $fileName -status $status
}

### Status TaskStages
# Get the stage from the status file
function Get-TaskStage
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName
    )

    $status = Get-StatusFile $fileName

    return $status.TaskStage

}

# Update the stage in the status file
function Set-TaskStage
{
    param
    (
        [Parameter (Mandatory)]
        [string]$fileName,
        [Parameter (Mandatory)]
        [int]$stage
    )

    $status = Get-StatusFile -fileName $fileName

    $status.TaskStage=$stage

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

### Functions to deal with the configuration
# get the next item that matches the $stage, or the next lowerst one > stage
function Get-TaskStages
{
    param
    (
        [Parameter (Mandatory)]
        [int]$stage,
        [Parameter (Mandatory)]
        [Object]$configuration
    )

    $foundValue=$null

    foreach ($taskStage in $configuration.TaskStages)
    {
        # Check if we've found the right one
        if ($taskstage.StageNumber -eq $stage )
        {
            return $taskStage
        }

        # Otherwise, check if the stage is greater than our tarket
        elseif ($taskStage.StageNumber -gt $stage)
        {
            #If so, check if our current value ($foundValue) is null 
            if ($null -eq $foundValue)
            {
                # If so, stash the current one
                $foundValue = $taskStage
            }
            # Check if the current version is less than the stashed version
            elseif ($taskStage.StageNumber -lt $foundValue.StageNumber)
            {
                # If so, then stash the new one
                $foundValue = $taskStage                
            }
        }
    }
    return $foundValue
}

### Functions to perform actions

# Windows store updates
function Update-StoreApps
{
	Write-Host "Upgrade all Windows Store apps. Please remember to log into the Windows Store when it opens."
    Read-Host -Prompt "Press Enter to start updating apps"
    Start-Process "ms-windows-store://downloadsandupdates"
    Read-Host -Prompt "Press Enter once the apps are updated"

}

# Install Windows Updates
# Returns true if updates are installed, false if none found
function Install-WindowsUpdates
{
    Write-Host "Searching for Windows Updates..."

    $updates=Get-WindowsUpdate -MicrosoftUpdate  

    if ($updates.Count -eq 0)
    {
        Write-Host "No updates found..."
        return $false
    }


    $updates | select KB,Size,Title | Tee-Object -Variable "updates" | Format-Table | Out-String | % {Write-Host $_}

    Write-Host "Installing Windows Updates. Please be patient, this may take some time..."
    Write-Host "After installing the update, the script may not re-start."

    Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install


    Write-Host "Finished Install of Windows updates"

    return $true
}

# Hide windows updates
function Hide-WindowsUpdates
{
    param
    (
        [Parameter (Mandatory)]
        [string]$IgnoreTitle
    )

    Write-Host "Hiding $IgnoreTitle..."

    $removedItems = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Title $IgnoreTitle -Hide

    while ($removedItems.Count -ne 0)
    {
        Write-Host "Removed $($removedItems.Title)"

        $removedItems = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Title $IgnoreTitle -Hide
    }
}

# Install a windows store app
function Install-StoreApp
{
    param
    (
        [Parameter (Mandatory)]
        [string]$ProductId,
        [string]$Text
    )

    if ($text)
    {
        Write-Host "Installing $Text"
    }

    # When winget supports Windows Store, update this
    winget install -s msstore -e "$ProductID"
}

# Install a windows store app
function Uninstall-StoreApp
{
    param
    (
        [Parameter (Mandatory)]
        [string]$ProductId,
        [string]$Text
    )

    if ($text)
    {
        Write-Host "Installing $Text"
    }

    # When winget supports Windows Store, update this
    winget uninstall -e "$ProductID"
}

# Install a winget package
function Install-WingetPackage
{
    param
    (
        [Parameter (Mandatory)]
        [string] $Id,
        [string] $Scope,
        [string[]] $AdditionalOptions
    )

    $scopeParam = ""

    if ($PSBoundParameters.ContainsKey("Scope"))
    {
        $scopeParam = "--scope"
    }
    Write-Host "Installing $Id..."
    winget install --exact $Id $scopeParam $Scope $AdditionalOptions
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

    Write-Host "Downloading $Url"

    
    # the progress bar slows down downloads
    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    Invoke-WebRequest -Uri $Url -OutFile "$filePath"

    $ProgressPreference = $oldProgressPreference

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

function Install-WindowsFeature
{
    param
    (
         [Parameter (Mandatory)]
         [string] $Feature
    )

    $Result = Enable-WindowsOptionalFeature -FeatureName $Feature -Online  -All -NoRestart
    if ($Result.RestartNeeded -eq $true)
    {
        return $True
    }
}

function Remove-WindowsFeature
{
    param
    (
         [Parameter (Mandatory)]
         [string] $Feature
    )

    $Result = Disable-WindowsOptionalFeature -FeatureName $Feature -Online  -Remove -NoRestart
    if ($Result.RestartNeeded -eq $true)
    {
        return $True
    }
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

# When we get an Office Install, perform the task
function Install-Office
{
    param
    (
         [Parameter (Mandatory)]
         [Object] $OfficeInstallTask
    )
    Write-Host "Installing Office..."
    $Office365_Deployment=$env:TEMP + "\officedeploymenttool_12827-20268.exe"
    $Office365_Extract=$env:TEMP + "\officedeploymenttool_12827-20268"
    $Office365_Tool=$Office365_Extract + "\setup.exe"
    $Office365_Config_File_Name="Office.xml"
    $Office365_Config_File=$Office365_Extract + "\" +$Office365_Config_File_Name

    # Download and extract the Office Deployment tool
    Install-DownloadedFile -Url "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_12827-20268.exe" -AdditionalOptions ("/extract:""$Office365_Extract""","/quiet")

    # Create the config file
    Create-OfficeDeploymentConfigurationFile -fileName $Office365_Config_File

    # Add the attributes to the configuration tag
    foreach ($configuratonAttribute in $OfficeInstallTask.ConfigurationAttributes)
    {
        Add-OfficeConfigurationAttributesToAdd -Attribute "$($configuratonAttribute.Attribute)" -value "$($configuratonAttribute.Value)" -FileName $Office365_Config_File
    }

    # Add the products
    foreach ($product in $OfficeInstallTask.Products)
    {
        Add-OfficeProduct -ProductID "$($product.ProductId)" -FileName $Office365_Config_File

        # Add the language
        if ($product.Language)
        {
            $language=$product.Language
            Add-OfficeProductLangage -ProductID "$($product.ProductId)" -LanguageID "$($language.LanguageId)" -FileName $Office365_Config_File

            foreach ($languageAttribute in $language.Attributes)
            {
                Add-OfficeProductLanguageAttribute -ProductID "$($product.ProductId)" -LanguageID MatchOS -Attribute "$($languageAttribute.Attribute)" -Value "$($languageAttribute.Value)" -FileName $Office365_Config_File
            }
        }

        # Add the Display
        if ($product.Display)
        {
            $display=$product.Display
            Add-OfficeProductDisplay -ProductID "$($product.ProductId)" -FileName $Office365_Config_File

            foreach ($displayAttribute in $display.Attributes)
            {
                Add-OfficeProductDisplayAttribute -ProductID "$($product.ProductId)" -Attribute "$($displayAttribute.Attribute)" -Value "$($displayAttribute.Value)" -FileName $Office365_Config_File
            }
        }

        # Exclude selected products
        foreach ($exclusion in $product.ExcludeComponents)
        {
            Add-OfficeProductExcludeApp -ProductID "$($product.ProductId)" -ExcludeAppID "$exclusion" -FileName $Office365_Config_File
        }
    }

    Write-Host "Installing Office 365"
    Start-Process "$Office365_Tool" -ArgumentList "/configure ""$Office365_Config_File""" -Wait

    Remove-Item -Path "$Office365_Extract" -Recurse

}
    
##### Start of commands...

### Make sure the config file exists and is setup
# We only want the user to pass the config filename on the command line
if ((Get-StatusStage -fileName $tempFile) -eq "")
{
    if (! $ConfigFile)
    {
        Add-Type -AssemblyName PresentationFramework
         $FileBrowser = New-Object Microsoft.Win32.OpenFileDialog -Property @{
            DefaultExt="*.json"; 
            Filter = "JSON documents (.json)|*.json"; 
            InitialDirectory = "$PWD"
        }
        $FileBrowserResult = $FileBrowser.ShowDialog()
        if ($FileBrowserResult -ne $true)
        {
            Write-Error "You need to select a configuration file." -ErrorAction Stop
        }
        $ConfigFile = $FileBrowser.FileName
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
        Write-Error "Configuration file should not be passed" -ErrorAction Stop
    }

    $ConfigFile = Get-StatusConfigFile -fileName $tempFile

    if (!(Test-Path $ConfigFile -PathType leaf))
    {
        Write-Error "Could not find configuration file $ConfigFile" -ErrorAction Stop
    }
}

$Config = Get-Configuration -fileName $ConfigFile

if ((Get-StatusStage -fileName $tempFile) -eq "")
{
    "@echo off" | Out-File -Encoding ascii -FilePath $startupFile
    "powershell -Command Set-Location `"`"$PWD`"`" ; `"`"$($MyInvocation.MyCommand.Path)`"`"" | Out-File -Append -Encoding ascii -FilePath $startupFile

    Set-StatusStage -fileName $tempFile -stage "wsl"
}

if ((Get-StatusStage -fileName $tempFile) -eq "wsl")
{
    # Install PowerShell Windows Update
    Write-Host "Installing PSWindowsUpdate..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force
    Install-Module -Name PSWindowsUpdate -Force

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
            $Result = Install-WindowsFeature -Feature Microsoft-Windows-Subsystem-Linux
            if ($Result -eq $true)
            {
                $NeedsReboot = $True
            }

            $Result = Install-WindowsFeature -Feature VirtualMachinePlatform
            if ($Result -eq $true)
            {
                $NeedsReboot = $True
            }
        }
    }
    Set-StatusStage -fileName $tempFile -stage "prepareUpdates"

    if ($NeedsReboot -eq $true)
    {
	    Read-Host -Prompt "Press Enter to reboot"

        shutdown /r /f /t 0

        exit
    }
}

if ((Get-StatusStage -fileName $tempFile) -eq "prepareUpdates")
{
    Add-WUServiceManager -MicrosoftUpdate

    Hide-WindowsUpdates -IgnoreTitle Silverlight
    Hide-WindowsUpdates -IgnoreTitle Preview

    Set-StatusStage -fileName $tempFile -stage "installUpdates"
}

if ((Get-StatusStage -fileName $tempFile) -eq "installUpdates")
{
    while (Install-WindowsUpdates)
    {

    }

    Set-StatusStage -fileName $tempFile -stage "wsl2"

}

if ((Get-StatusStage -fileName $tempFile) -eq "wsl2")
{
    if ($Config.InstallWsl)
    {
        if ($Config.InstallWsl -eq $true)
        {
            # WSL2 is only supported on Windows 2004 and later
            # Since creating this, WSL 2 has been backported to Windows 10 1903, but I can't be bothered setting up the
            # checks because I don't intend to run older versions of Windows. Feel free to file a PR
            if ($windowsVersion -ge $windows2004)
            {
                # The WSL kernel is now picked up as part of Software Update. Leaving this here just in case...
                # see https://aka.ms/wsl2kernel

                #Install-DownloadedFile -Url "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -AdditionalOptions ("/quiet")

                # Set the wsl default version before we begin
                wsl --set-default-version 2
            }
        }
    }
    Set-StatusStage -fileName $tempFile -stage "installUpdatesSecondStage"
}

# If we've done a feature update, we can check for updates again...
if ((Get-StatusStage -fileName $tempFile) -eq "installUpdatesSecondStage")
{
    while (Install-WindowsUpdates)
    {

    }

    Set-StatusStage -fileName $tempFile -stage "updateStoreApps"
}

if ((Get-StatusStage -fileName $tempFile) -eq "updateStoreApps")
{
    # Windows store updates page
    Update-StoreApps
	
    Set-StatusStage -fileName $tempFile -stage "installTasks"
}

while ((Get-StatusStage -fileName $tempFile) -eq "installTasks")
{
    [int]$nextTaskStage=Get-TaskStage -fileName $tempFile

    $taskStage = Get-TaskStages -stage $nextTaskStage -configuration $Config

    if ($null -eq $taskStage)
    {
        Write-Host "End of tasks..."
        Set-StatusStage -fileName $tempFile -stage "cleanupAutoBoot"
    }
    else
    {
        Write-Host "Starting stage $($taskStage.StageNumber)."
    }

    if ($taskStage.StartMessage)
    {
        Write-Host "$($taskStage.StartMessage)"
    }

    # do this only if we haven't skipped past
    if ((Get-StatusStage -fileName $tempFile) -eq "installTasks")
    {
        $NeedsReboot = $false

        # For Iterate through each task in this list...
        foreach ($task in $taskStage.tasks)
        {
            switch ($task.Type)
            {
                # Install a store app
                "microsoftStore"
                {
                    Install-StoreApp -ProductId $task.Id -Text $task.Text
                }

                # Uninstall a store app
                "removeMicrosoftStore"
                {
                    Uninstall-StoreApp -ProductId $task.Id -Text $task.Text
                }


                # Install an app through winget
                "winget"
                {
                    $wingetParams = @{
                        Id = $task.Id;
                    } 

                    if ($task.Scope)
                    {
                        $wingetParams.Add("Scope", $task.Scope)
                    }
                    if ($task.AdditionalOptions)
                    {
                        $wingetParams.Add("AdditionalOptions", [string[]] $task.AdditionalOptions)
                    }
                    Install-WingetPackage @wingetParams
                }
                # run an execurable
                "exec"
                {
                    if ($task.Text)
                    {
                        Write-Host "$($task.Text)"
                    }
                    Start-Process "$($task.Executable)" -Wait
                }
                # Download and run an executable
                "download"
                {
                    if ($task.Text)
                    {
                        Write-Host "$($task.Text)"
                    }
                    if ($task.WaitMessage)
                    {
                        Install-DownloadedFile -Url "$($task.Url)" -WaitMessage "$($task.WaitMessage)"
                    }
                    else
                    {
                        Install-DownloadedFile -Url "$($task.Url)"
                    }
                }
                # Install a Windows Feature
                "addWindowsFeature"
                {
                    Write-Host "Installing Windows Feature $($task.Feature)..."
                    $Result=Install-WindowsFeature -Feature "$($task.Feature)"

                    if ($Result -eq $true)
                    {
                        $NeedsReboot = $True
                    }
                }
                # Install a Windows Feature
                "removeWindowsFeature"
                {
                    Write-Host "Removing Windows Feature: $($task.Feature)..."
                    $Result=Remove-WindowsFeature -Feature "$($task.Feature)"

                    if ($Result -eq $true)
                    {
                        $NeedsReboot = $True
                    }
                }
                # Install Office 2016/2019/365
                "office"
                {
                    Install-Office -OfficeInstallTask $task
                }
            }
        }

        $nextTaskStage = $taskStage.StageNumber + 1

        Set-TaskStage -fileName $tempFile -stage $nextTaskStage

        # If we are still in stage 6
        if ((Get-StatusStage -fileName $tempFile) -eq "installTasks")
        {
            if ($taskStage.FinishMessage)
            {
                Write-Host $taskStage.FinishMessage
            }
            else
            {
                Write-Host "Finished task stage $($taskStage.StageNumber)."
            }

            # If the stage does not have a finish action, we tret is as continue
            if ($taskStage.FinishAction)
            {
                switch ($taskStage.FinishAction)
                {
                    "reboot"
                    {
                        Read-Host -Prompt "Press Enter to reboot"

                        shutdown /r /f /t 0

                        exit
                    }
                    "exit"
                    {
                        Read-Host -Prompt "Press Enter to exit the script. You will need to re-run the script."
                        exit
                    }
                }
            }

            # If we need a reboot
            if ($NeedsReboot)
            {
                Read-Host -Prompt "Press Enter to reboot"

                shutdown /r /f /t 0

                exit
            }
        }
    }
}

if ((Get-StatusStage -fileName $tempFile) -eq "cleanupAutoBoot")
{
    Remove-Item -Path $startupFile
    Set-StatusStage -fileName $tempFile -stage "finished"
}
