#Written by Andreas Aaris-Larsen
#This script assumes PSv5 is used, and some features will not work with v2
#Script completed and verified in lab 2019-06-11
#Script verified in real environment 2019-XX-XX

clear

$credential = Get-Credential
$timestamp = ($(get-date -f yyyyMMdd)+$(get-date -f HHmmss))
$foldername = "dirlists-"+$timestamp

#Settings
[System.IO.Directory]::SetCurrentDirectory($PWD) | Out-Null                           #Make .NET use the same PWD as Powershell



Write-Host "Get-DirLists" $(Get-Date)
Write-Host "--------------------------------------------------------------------"

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
    Invoke-Command -Session $session -Command {$drives = Get-PSDrive -PSProvider 'FileSystem'} | Out-Null 
    Invoke-Command -Session $session -Command {$listing = foreach($drive in $drives){Get-ChildItem -Path $drive.Root -Recurse -File -ErrorAction SilentlyContinue -Force | % { $_.FullName }}} -AsJob | Out-Null
    Write-Host "Running command...: " $session.Name.toString()
}

Write-Host "Waiting for jobs to finish..."
Get-Job | Wait-Job | Out-Null

Write-Host "Retrieving results..."
foreach($session in Get-PSSession)
{
    $path = ".\acquired\"+$foldername+"\"+$session.ComputerName.ToString()+"-dirlists-"+$timestamp+".txt"
    $local = Invoke-Command -Session $session -ScriptBlock{$listing}
    $local | Out-File -FilePath $path
    Write-Host "Results retrieved: " $session.Name.toString()
}

Write-Host "Cleaning up..."
#Cleanup

Remove-PSSession *
Remove-Job *

<# This feature is commented out, as it takes the localhost ages to compile the merged files. I recommend grepping the individual files instead.

Write-Host "Merging files..."
$files = Get-ChildItem acquired\$foldername
$mergedFile = ".\acquired\"+$foldername+"\"+"dirlists-"+$timestamp+"-merged.txt"
foreach($file in $files)
{
    $hostname = ($file -split "-dirlists-")[0]
    Write-Host $hostname
    foreach($line in [System.IO.File]::ReadLines($file.FullName))
    {
        $hostname + " :: " + $line | Out-File -Append -FilePath $mergedFile
    }
}
Write-Host "Merger completed."
#>

Write-Host ""
Write-Host "Acquisition completed."  $(Get-Date)
Write-Host "--------------------------------------------------------------------"