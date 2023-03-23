#Written by Andreas Aaris-Larsen
#This script assumes PSv5 is used, and some features will not work with v2
#Script completed and verified in lab 2019-04-25
#Script verified in real environment 2019-XX-XX

clear

$credential = Get-Credential
$timestamp = ($(get-date -f yyyyMMdd)+$(get-date -f HHmmss))
$foldername = "prefetch-"+$timestamp

#Settings
[System.IO.Directory]::SetCurrentDirectory($PWD) | Out-Null                           #Make .NET use the same PWD as Powershell



Write-Host "Get-Prefetch" $(Get-Date)
Write-Host "--------------------------------------------------------------------"

Write-Host "Creating output folder..."
New-Item -ItemType Directory -Path .\acquired -Name $foldername | Out-Null

Write-Host "Establishing sessions with targets..."
foreach($target in [System.IO.File]::ReadLines(".\targets.txt"))             #iterate through the targets file
{
    New-PSSession -ComputerName $target -Credential $credential -Name $target
    #Write-Host "Connection established: " $target
}    

Write-Host "Retrieving result files..."
foreach($session in Get-PSSession)
{
    Write-Host "Retrieving files: " $session.Name.toString()
    New-Item -ItemType Directory -Path .\acquired\$foldername -Name $session.ComputerName.ToString() | Out-Null
    $path = ".\acquired\"+$foldername+"\"+$session.ComputerName.ToString()+"\"
    Copy-Item -FromSession $session -Path "C:\Windows\prefetch" -Destination $path -Recurse
    Write-Host "Files retrieved : " $session.Name.toString()
}

Write-Host "Cleaning up..."
#Cleanup

Remove-PSSession *

Write-Host ""
Write-Host "Acquisition completed."  $(Get-Date)
Write-Host "--------------------------------------------------------------------"