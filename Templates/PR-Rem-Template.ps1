# Template for Proactive Remediations


#Try-Catch for error handling
Try {
    # After you export the RegKey, be sure you copy/paste it HERE: https://reg2ps.azurewebsites.net/
    # This will create the detection script and the remediation script. 
    
    if (condition) {
        <# Action to perform if the condition is true #>
        
    }
    
}Catch{
    #captures and reports the exception errors of the script
    Write-Host $_.Exception
    Exit 2000
}
