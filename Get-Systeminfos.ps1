#Written by Andreas Aaris-Larsen
#This script assumes PSv5 is used, and some features will not work with v2
#Script completed and verified in lab 2019-06-11
#Script verified in real environment 2019-XX-XX

clear

#$credential = Get-Credential
$credential = New-Object System.Management.Automation.PSCredential("fear\administrator", (ConvertTo-SecureString "Password123!" -AsPlainText -Force))
$timestamp = ($(get-date -f yyyyMMdd)+$(get-date -f HHmmss))
$foldername = "systeminfos-"+$timestamp

#Settings
[System.IO.Directory]::SetCurrentDirectory($PWD) | Out-Null                           #Make .NET use the same PWD as Powershell

#TODO: it doesn't show PID or process name on servers


Write-Host "Get-Systeminfos" $(Get-Date)
Write-Host "--------------------------------------------------------------------"
Write-Host ""

Write-Host "Creating output folder..."
New-Item -ItemType Directory -Path .\acquired -Name $foldername | Out-Null

Write-Host "Establishing sessions with targets..."
foreach($target in [System.IO.File]::ReadLines(".\targets.txt"))             #iterate through the targets file
{
    New-PSSession -ComputerName $target -Credential $credential -Name $target
    #Write-Host "Connection established: " $target
}    

foreach($session in Get-PSSession)
{   
    Invoke-Command -Session $session -Command {$returnvalue = systeminfo} -AsJob | Out-Null
    Write-Host "Running command...: " $session.Name.toString()
}

Write-Host "Waiting for jobs to finish..."
Get-Job | Wait-Job | Out-Null

Write-Host "Retrieving results..."
foreach($session in Get-PSSession)
{
    $path = ".\acquired\"+$foldername+"\"+$session.ComputerName.ToString()+"-systeminfos-"+$timestamp+".txt"
    $local = Invoke-Command -Session $session -ScriptBlock{$returnvalue}
    $local | Out-File -FilePath $path

    Write-Host "Results retrieved: " $session.Name.toString()
}

Write-Host "Cleaning up..."
#Cleanup

Remove-PSSession *
Remove-Job *

Write-Host ""
Write-Host "Acquisition completed."  $(Get-Date)
Write-Host "--------------------------------------------------------------------"