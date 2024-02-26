<#
.SYNOPSIS
This code snippet provides a base for a script to run against a group of remote servers.

.DESCRIPTION
This code snippet provides a base for a script to run against a group of remote servers. The base example pulls computers from a 
specific OU in active directory. Alternative methods could include an Array of Server names, or importing a CSV of server names.
The use of an OU requires the Active Directory PowerShell module to be installed, though it allows for more dynamic execution of 
these types of scripts. 

.EXAMPLE
Array Example: $servers = @("Server1","Server2","Server3")

CSV Import Example: $servers = Import-csv -Path C:\Path\To\CSV.file.csv 
-Ensure you have the Name & DNSHostName as column headers for your CSV import file

.NOTES
Author: Smitty
Version: 1.0
Date: 2/20/24
#>



# Specify the OU distinguished name
$ou = "OU=Servers,DC=domain,DC=com"  

# Retrieve all servers from the specified OU
$servers = Get-ADComputer -Filter * -SearchBase $ou -Properties Name, WhenCreated 

Foreach ($s in $servers) {
    
    $scriptBlock = {
        # Enter Code to be run remotely between these script block brackets


    }

    try {
        # create a new PowerShell session to the remote server
        $session = New-PSSession -ComputerName $s.DNSHostName -ErrorAction Stop

        # Execute the script block on the remote server within the PSSession
        Invoke-Command -Session $session -ScriptBlock $scriptBlock -ErrorAction Stop

        # Close the PSSession
        Remove-PSSession $session
    }
    Catch {
        # Write an error for failed connections so you know which ones did not run
        Write-Host "Could not connect to: " $s.Name -ForegroundColor Red
    }
} 

