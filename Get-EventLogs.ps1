#Written by Andreas Aaris-Larsen
#This script assumes PSv5 is used, and some features will not work with v2
#Script completed and verified in lab 2024-07-31
#Script verified in real environment 2024-XX-XX

clear

$credential = Get-Credential
#$credential = New-Object System.Management.Automation.PSCredential("fear\administrator", (ConvertTo-SecureString "Password123!" -AsPlainText -Force))
$timestamp = ($(get-date -f yyyyMMdd)+$(get-date -f HHmmss))
$foldername = "eventlogs-"+$timestamp

#Settings
[System.IO.Directory]::SetCurrentDirectory($PWD) | Out-Null                           #Make .NET use the same PWD as Powershell



Write-Host "Get-EventLogs" $(Get-Date)
Write-Host "--------------------------------------------------------------------"

Write-Host "Creating output folder..."
New-Item -ItemType Directory -Path .\acquired -Name $foldername | Out-Null

Write-Host "Establishing sessions with targets..."
foreach($target in [System.IO.File]::ReadLines(".\targets.txt"))             #iterate through the targets file
{
    New-PSSession -ComputerName $target -Credential $credential -Name $target
    #Write-Host "Connection established: " $target
}    

Write-Host ""

foreach($session in Get-PSSession)
{   
    Invoke-Command -Session $session -Command {$eventLogs = Get-WinEvent -ListLog *} | Out-Null     
    Write-Host "Enumerating logs...: " $session.Name.toString()
}
Get-Job | Wait-Job | Out-Null

Write-Host ""

foreach($session in Get-PSSession)
{   
    Invoke-Command -Session $session -Command {$destinationPath = "C:\DFIR\Logs"; if (!(Test-Path $destinationPath)) { New-Item -Path $destinationPath -ItemType Directory | Out-Null }; foreach ($log in Get-WinEvent -ListLog *) { $logName = $log.LogName; $safeLogName = $logName -replace '[\\/:*?"<>|]', '_'; $outputFile = "$destinationPath\$safeLogName.evtx"; wevtutil epl $logName $outputFile }} -AsJob | Out-Null
    Write-Host "Exporting logs to local system...: " $session.Name.toString()
}
Get-Job | Wait-Job | Out-Null

Write-Host ""

Write-Host "Retrieving log files..."
foreach($session in Get-PSSession)
{
    $path = ".\acquired\"+$foldername+"\"+$session.ComputerName.ToString()+"\"
    Copy-Item -FromSession $session -Path "C:\DFIR\Logs" -Destination $path -Recurse
    Write-Host "Files retrieved: " $session.Name.toString()
}



Write-Host ""
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