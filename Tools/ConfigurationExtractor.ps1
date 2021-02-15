param
(
    [Parameter (Mandatory)]
    [string]$Path
)


if(Test-Path -PathType Container -Path $path)
{
    Remove-Item -Path "$Path" -Recurse | Out-Null
}

function Convert-LineEndings
{
    param
    (
        [Parameter (Mandatory)]
        [string] $SourcePath,
        [Parameter (Mandatory)]
        [string] $DestPath,
        [Parameter (Mandatory)]
        [string] $FileName
    )

    $text = [IO.File]::ReadAllText($SourcePath + "\" + $FileName) -replace "`r `n", "`n"
    [IO.File]::WriteAllText($DestPath + "\" + $FileName, $text)
}

New-Item -Path "$Path" -ItemType Directory | Out-Null

$Path=Convert-Path $Path

$RawPath=$Path + "\Raw"

New-Item -Path "$RawPath" -ItemType Directory | Out-Null

Write-Host "Getting Windows Edition"
Get-WindowsEdition -Online| Out-String -Width 4096 | Out-File "$RawPath\WindowsEdition.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName WindowsEdition.txt

Write-Host "Getting Installed Programs"
Get-WmiObject -Class win32_product | Sort-Object -Property IdentifyingNumber | Out-String -Width 4096 | Out-File "$RawPath\InstalledPrograms.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName InstalledPrograms.txt

Write-Host "Getting AppX Bundles"
Get-AppxPackage -AllUsers -PackageTypeFilter Bundle | Select-Object Name,Publisher,Architecture,ResourceID,Version,PackageFullName,PublisherID | Sort-Object -Property PackageFullName | Out-String -Width 4096 | Out-File "$RawPath\AppXBundles.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName AppXBundles.txt

Write-Host "Getting AppX Frameworks"
Get-AppxPackage -AllUsers -PackageTypeFilter Framework | Select-Object Name,Publisher,Architecture,ResourceID,Version,PackageFullName,PublisherID | Sort-Object -Property PackageFullName | Out-String -Width 4096 | Out-File "$RawPath\AppXFrameworks.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName AppXFrameworks.txt

Write-Host "Getting AppX Mains"
Get-AppxPackage -AllUsers -PackageTypeFilter Main | Select-Object Name,Publisher,Architecture,ResourceID,Version,PackageFullName,PublisherID | Sort-Object -Property PackageFullName | Out-String -Width 4096 | Out-File "$RawPath\AppXMain.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName AppXMain.txt

Write-Host "Getting AppX Optional"
Get-AppxPackage -AllUsers -PackageTypeFilter Optional | Select-Object Name,Publisher,Architecture,ResourceID,Version,PackageFullName,PublisherID | Sort-Object -Property PackageFullName | Out-String -Width 4096 | Out-File "$RawPath\AppXOptional.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName AppXOptional.txt

Write-Host "Getting AppX Resources"
Get-AppxPackage -AllUsers -PackageTypeFilter Resource | Select-Object Name,Publisher,Architecture,ResourceID,Version,PackageFullName,PublisherID | Sort-Object -Property PackageFullName | Out-String -Width 4096 | Out-File "$RawPath\AppXResource.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName AppXResource.txt

Write-Host "Getting AppX Xaps"
Get-AppxPackage -AllUsers -PackageTypeFilter Xap | Select-Object Name,Publisher,Architecture,ResourceID,Version,PackageFullName,PublisherID | Sort-Object -Property PackageFullName | Out-String -Width 4096 | Out-File "$RawPath\AppXXaps.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName AppXXaps.txt

Write-Host "Getting Installed Drivers"
Get-WindowsDriver -Online -All | Sort-Object -Property OriginalFileName | Select-Object OriginalFileName,Inbox,ClassName,BootCritical,ProviderName,Date,Version | Out-String -Width 4096 | Out-File "$RawPath\Drivers.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName Drivers.txt

Write-Host "Getting Installed Additional Drivers"
Get-WindowsDriver -Online | Sort-Object -Property OriginalFileName | Select-Object OriginalFileName,Inbox,ClassName,BootCritical,ProviderName,Date,Version | Out-String -Width 4096 | Out-File "$RawPath\OEMDrivers.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName OEMDrivers.txt

Write-Host "Getting Provisioned AppX Packages"
Get-AppxProvisionedPackage -online | Sort-Object -Property PackageName | Out-String -Width 4096 | Out-File "$RawPath\AppXProvisioned.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName AppXProvisioned.txt

Write-Host "Getting Windows Features"
Get-WindowsOptionalFeature -Online | Sort-Object -Property FeatureName | Out-String -Width 4096 | Out-File "$RawPath\WindowsFeatures.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName WindowsFeatures.txt

Write-Host "Getting Windows Capabilites"
Get-WindowsCapability -Online | Sort-Object -Property Name | Out-String -Width 4096 | Out-File "$RawPath\WindowsCapabilities.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName WindowsCapabilities.txt

Write-Host "Getting Windows Packages"
Get-WindowsPackage -Online | Sort-Object -Property PackageName | Out-String -Width 4096 | Out-File "$RawPath\WindowsPackages.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName WindowsPackages.txt

Write-Host "Getting Windows Scheduled Tasks"
Get-ScheduledTask | Sort-Object -Property TaskPath | Select TaskName,TaskPath,Author,Date | Out-String -Width 4096 | Out-File "$RawPath\ScheduledTasks.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName ScheduledTasks.txt

Write-Host "Getting Windows User Language List"
Get-WinUserLanguageList | Out-String -Width 4096 | Out-File "$RawPath\LanguageList.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName LanguageList.txt

Write-Host "Getting Windows System Locale"
Get-WinSystemLocale | Out-String -Width 4096 | Out-File "$RawPath\WindowsSystemLocale.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName WindowsSystemLocale.txt

Write-Host "Getting Windows Home Location"
Get-WinHomeLocation | Out-String -Width 4096 | Out-File "$RawPath\WindowsHomeLocation.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName WindowsHomeLocation.txt

Write-Host "Getting Partitions"
Get-Partition | select PartitionNumber,Size,Type,IsActive,IsBoot,IsHidden,IsSystem | Out-String -Width 4096 | Out-File "$RawPath\Parition.txt"
Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName Parition.txt
