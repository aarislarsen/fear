#Written by Andreas Aaris-Larsen
#This script assumes PSv5 is used, and some features will not work with v2
#Script completed and verified in lab 2019-04-25
#Script verified in real environment 2019-06-04

clear

$credential = Get-Credential
$timestamp = ($(get-date -f yyyyMMdd)+$(get-date -f HHmmss))
$foldername = "autorunsc-"+$timestamp

#Settings
[System.IO.Directory]::SetCurrentDirectory($PWD) | Out-Null                           #Make .NET use the same PWD as Powershell



Write-Host "Get-Autorunsc" $(Get-Date)
Write-Host "--------------------------------------------------------------------"

Write-Host "Creating output folder..."
New-Item -ItemType Directory -Path .\acquired -Name $foldername | Out-Null

Write-Host "Establishing sessions with targets..."
foreach($target in [System.IO.File]::ReadLines(".\targets.txt"))             #iterate through the targets file
{
    New-PSSession -ComputerName $target -Credential $credential -Name $target
    #Write-Host "Connection established: " $target
}    

Write-Host "Pushing autorunsc and running it..."
foreach($session in Get-PSSession)
{    
    Invoke-Command -Session $session -Command {New-Item -Path C:\DFIR -type directory -Force } | Out-Null
    Write-Host "Folder created: " $session.Name.toString()    
}
foreach($session in Get-PSSession)
{    
    Copy-Item -ToSession $session -Path ".\binaries\autorunsc.exe" -Destination "C:\DFIR\autorunsc.exe" | Out-Null
    Write-Host "Tool copied: " $session.Name.toString()    
}
foreach($session in Get-PSSession)
{    
    Invoke-Command -Session $session -Command {c:\DFIR\autorunsc.exe -a * -s -h -c /accepteula > c:\DFIR\$env:COMPUTERNAME-autorunsc-results.txt} -AsJob | Out-Null
    Write-Host "Running tool: " $session.Name.toString()
}

Write-Host "Waiting for jobs to finish..."
Get-Job | Wait-Job | Out-Null

Write-Host "Retrieving result files..."
foreach($session in Get-PSSession)
{
    $path = ".\acquired\"+$foldername+"\"+$session.ComputerName.ToString()+"-autorunsc-results-"+$timestamp+".txt"
    Copy-Item -FromSession $session -Path "C:\DFIR\*-autorunsc-results.txt" -Destination $path
    Write-Host "File retrieved: " $session.Name.toString()
}

Write-Host "Cleaning up..."
#Cleanup
foreach($session in Get-PSSession)
{
    Invoke-Command -Session $session -Command {Remove-Item c:\DFIR -Recurse}
    Write-Host "Cleaned: " $session.Name.toString()
}
Remove-PSSession *
Remove-Job *

Write-Host ""
Write-Host "Acquisition completed."  $(Get-Date)
Write-Host "--------------------------------------------------------------------"