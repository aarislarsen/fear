#Written by Andreas Aaris-Larsen
#This script assumes PSv5 is used, and some features will not work with v2
#Script completed and verified in lab 2019-06-28
#Script verified in real environment 2019-XX-XX

clear

$credential = Get-Credential
#$credential = New-Object System.Management.Automation.PSCredential("fear\administrator", (ConvertTo-SecureString "Password123!" -AsPlainText -Force))
$timestamp = ($(get-date -f yyyyMMdd)+$(get-date -f HHmmss))
$foldername = "dirlists-with-hashes-"+$timestamp

#Settings
[System.IO.Directory]::SetCurrentDirectory($PWD) | Out-Null                           #Make .NET use the same PWD as Powershell



Write-Host "Get-DirListsWithHashes" $(Get-Date)
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
    Write-Host "Enumerating drives...: " $session.Name.toString()
}
Get-Job | Wait-Job | Out-Null

foreach($session in Get-PSSession)
{   
    Invoke-Command -Session $session -Command {$listing = foreach($drive in $drives){Get-ChildItem -Path $drive.Root -Recurse -File -ErrorAction SilentlyContinue -Force | % { $_.FullName }}} -AsJob | Out-Null
    Write-Host "Indexing system...: " $session.Name.toString()
}
Get-Job | Wait-Job | Out-Null

foreach($session in Get-PSSession)
{   
    Invoke-Command -Session $session -Command {$hashes = "" ;foreach($uri in $listing){$FileData = [System.IO.File]::ReadAllBytes($uri); $hash = [System.Security.Cryptography.SHA256]::Create(); $hashbytes = $hash.ComputeHash($FileData); $paddedHex = ""; $hashbytes | ForEach-Object { $byte = $_;    $byteInHex = [String]::Format("{0:X}", $byte);  $paddedHex += $byteInHex.PadLeft(2,"0")     };   $hashes += "$paddedHex ## $env:computername ## $uri `n"}} -AsJob | Out-Null
    Write-Host "Generating hashes...: " $session.Name.toString()
}   

Write-Host "Waiting for jobs to finish. This will take a while..."
Get-Job | Wait-Job | Out-Null

Write-Host "Retrieving results..."
foreach($session in Get-PSSession)
{
    $path = ".\acquired\"+$foldername+"\"+$session.ComputerName.ToString()+"-dirlists-with-hashes-"+$timestamp+".txt"
    $local = Invoke-Command -Session $session -ScriptBlock{$hashes}
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