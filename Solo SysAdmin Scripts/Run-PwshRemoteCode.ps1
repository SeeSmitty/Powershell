<#
.SYNOPSIS
This code snippet sets the DNS server addresses for all servers in a specified OU.

.DESCRIPTION


.NOTES
Author: Smitty
Version: 1.0
Date: 2/20/24
#>

# Could also be an array of server names instead of an OU
# Example: $servers = @("Server1","Server2","Server3")

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

