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
        [string] $FileName
    )

    $text = [IO.File]::ReadAllText($FileName) -replace "`r `n", "`n"
    [IO.File]::WriteAllText($FileName, $text)
}

New-Item -Path "$Path" -ItemType Directory | Out-Null

$Path=Convert-Path $Path

#Write-Host "Getting Windows Edition"
#Get-WindowsEdition -Online| Out-String -Width 4096 | Out-File "$RawPath\WindowsEdition.txt"
#Convert-LineEndings -SourcePath $RawPath -DestPath $Path -FileName WindowsEdition.txt

Set-Location $Path

Write-Host "Extracting OEM Drivers"
Export-WindowsDriver -Online -Verbose -Destination  $Path 

pnputil.exe /enum-devices /connected > $Path\ConnectedDrivers.txt
Convert-LineEndings -FileName $Path\ConnectedDrivers.txt

pnputil.exe /enum-devices /problem > $Path\ProblemDrivers.txt
Convert-LineEndings -FileName $Path\ProblemDrivers.txt