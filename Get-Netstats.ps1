#Written by Andreas Aaris-Larsen
#This script assumes PSv5 is used, and some features will not work with v2
#Script completed and verified in lab 2019-06-11
#Script verified in real environment 2019-XX-XX

clear

$credential = Get-Credential
$timestamp = ($(get-date -f yyyyMMdd)+$(get-date -f HHmmss))
$foldername = "netstats-"+$timestamp

#Settings
[System.IO.Directory]::SetCurrentDirectory($PWD) | Out-Null                           #Make .NET use the same PWD as Powershell

#TODO: it doesn't show PID or process name on servers


Write-Host "Get-Netstats" $(Get-Date)
Write-Host "--------------------------------------------------------------------"
Write-Host "This script creates two sets of output. One with the powershell Get-TCPConnection, the other with netstat-anb. This is because some version of Windwos/Powershell for some reason doesn't include the owning process in the output, so this is to be sure not to miss anything."
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
    Invoke-Command -Session $session -Command {$output = @(); $connections = Get-NetTCPConnection ; foreach($connection in $connections){$id =($connection |Select OwningProcess -ExpandProperty OwningProcess); $name = (Get-Process -Id $id | Select Name -ExpandProperty Name) ; $local = $connection.LocalAddress ; $port = $connection.LocalPort ; $remote = $connection.RemoteAddress ; $rpot = $connection.RemotePort ; $state = $connection.State ; $process =$connection.OwningProcess ;  $obj = New-Object -TypeName psobject ; $obj | Add-Member NoteProperty -Name LocalAddress -Value $local ; $obj | Add-Member NoteProperty -Name LocalPort -Value $port ; $obj | Add-Member NoteProperty -Name RemoteAddress -Value $remote ; $obj | Add-Member NoteProperty -Name RemotePort -Value $rpot ; $obj | Add-Member NoteProperty -Name State -Value $state ; $obj | Add-Member NoteProperty -Name OwningProcess -Value $process ; $obj | Add-Member NoteProperty -Name ProcessName -Value $name ; $output += $obj} ; $returnvalue = ($output | Format-Table); $output2 = netstat -anb} -AsJob | Out-Null
    #Use this one if you only want listening services
    #Invoke-Command -Session $session -Command {$output = @(); $connections = (Get-NetTCPConnection | ? {($_.State -eq "Listen")}) ; foreach($connection in $connections){$id =($connection |Select OwningProcess -ExpandProperty OwningProcess); $name = (Get-Process -Id $id | Select Name -ExpandProperty Name) ; $local = $connection.LocalAddress ; $port = $connection.LocalPort ; $remote = $connection.RemoteAddress ; $rpot = $connection.RemotePort ; $state = $connection.State ; $process =$connection.OwningProcess ;  $obj = New-Object -TypeName psobject ; $obj | Add-Member NoteProperty -Name LocalAddress -Value $local ; $obj | Add-Member NoteProperty -Name LocalPort -Value $port ; $obj | Add-Member NoteProperty -Name RemoteAddress -Value $remote ; $obj | Add-Member NoteProperty -Name RemotePort -Value $rpot ; $obj | Add-Member NoteProperty -Name State -Value $state ; $obj | Add-Member NoteProperty -Name OwningProcess -Value $process ; $obj | Add-Member NoteProperty -Name ProcessName -Value $name ; $output += $obj} ; $returnvalue = ($output | Format-Table)} -AsJob
    Write-Host "Running command...: " $session.Name.toString()
}

Write-Host "Waiting for jobs to finish..."
Get-Job | Wait-Job | Out-Null

Write-Host "Retrieving results..."
foreach($session in Get-PSSession)
{
    $path = ".\acquired\"+$foldername+"\"+$session.ComputerName.ToString()+"-netstats-"+$timestamp+".txt"
    $local = Invoke-Command -Session $session -ScriptBlock{$returnvalue}
    $local | Out-File -FilePath $path

    $path = ".\acquired\"+$foldername+"\"+$session.ComputerName.ToString()+"-netstats-anb-"+$timestamp+".txt"
    $local = Invoke-Command -Session $session -ScriptBlock{$output2}
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