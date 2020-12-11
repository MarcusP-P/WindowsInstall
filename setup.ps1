#Requires -RunAsAdministrator
# Copyright (c) 2020, Marcus Pallinger

# You will need to set the execution policy for scripts
# for me: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# You may also need to run Unblock-File against this script

param 
(
    [string] $ConfigFile
)

# the progress bar slows down downloads
$ProgressPreference = 'SilentlyContinue'

# The buildnumber of this version of Windows
$WindowsVersion=[long]::Parse((Get-WmiObject Win32_OperatingSystem).BuildNumber)

# Known Build Numbers
$windows20H2=19042
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
	Write-Host "Winget only supports Windows 10 1703 or later. Because this script pretty much requires Winget, it will not run on an older version"
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
        $status=@{Stage=0;ConfigFile="";TaskStage=0}

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
            if ($foundValue -eq $null)
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

    Write-Host "Installing $Id..."
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

    Write-Host "Downloading $wsl2_kernel"

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
    Set-StatusStage -fileName $tempFile -stage 1

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
	
    Set-StatusStage -fileName $tempFile -stage 2

	Write-Host "Please install any windows updates. If you do not need to reboot this device, re-run this script"
	
    exit
}

if ((Get-StatusStage -fileName $tempFile) -eq 2)
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

                # the WSL kernel needs to be downlaoded manually for now.
                # see https://aka.ms/wsl2kernel

                Install-DownloadedFile -Url "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -AdditionalOptions ("/quiet")

                # Set the wsl default version before we begin
                wsl --set-default-version 2
            }
        }
    }
    Set-StatusStage -fileName $tempFile -stage 3
}

if ((Get-StatusStage -fileName $tempFile) -eq 3)
{
    # Windows store updates page
    Update-StoreApps
	
    Set-StatusStage -fileName $tempFile -stage 4
}

while ((Get-StatusStage -fileName $tempFile) -eq 4)
{
    [int]$nextTaskStage=Get-TaskStage -fileName $tempFile

    $taskStage = Get-TaskStages -stage $nextTaskStage -configuration $Config

    if ($taskStage -eq $null)
    {
        Write-Host "End of tasks..."
        Set-StatusStage -fileName $tempFile -stage 5
    }

    Write-Host "Starting stage $($taskStage.StageNumber)."

    if ($taskStage.StartMessage)
    {
        Write-Host "$($taskStage.StartMessage)"
    }

    # do this only if we haven't skipped past
    if ((Get-StatusStage -fileName $tempFile) -eq 4)
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

                # Install an app through winget
                "winget"
                {
                    if ($task.AdditionalOptions)
                    {
                        Install-WingetPackage -Id $task.Id -AdditionalOptions ([string[]] $task.AdditionalOptions)
                    }
                    else
                    {
                        Install-WingetPackage -Id $task.Id                      
                    }
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
                    Write-Host "Installing $($task.Feature)..."
                    $Result=Install-WindowsFeature -Feature "$($task.Feature)"

                    if ($Result -eq $true)
                    {
                        $NeedsReboot = $True
                    }
                }
                # Install a Windows Feature
                "removeWindowsFeature"
                {
                    Write-Host "Installing $($task.Feature)..."
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

        # If we are still in stage 4
        if ((Get-StatusStage -fileName $tempFile) -eq 4)
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