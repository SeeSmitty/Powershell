<#
.SYNOPSIS
The purpose of this script is to provide an example for pagination in MS Graph PowerShell SDK

.DESCRIPTION
The purpose of this script is to provide an example for pagination in MS Graph PowerShell SDK. This allows 
for a template for building pagination into powershell scripts leverging MS Graph. 

.LINK
https://seesmitty.com/leverage-invoke-restmethod-for-more-powerful-scripting-part-2/

.NOTES
Author: Smitty
Date: 10-06-2022
Version: 1.0.1

#>
$Client = ""
$secret = ""
$tenant = ""


#details for connecting via MS Graph
$body = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $Client
    Client_Secret = $secret
}
#grab a token for authentication
$connection = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" -Method POST -Body $body
 
#function to grab a list of all groups
function Get-GroupList {
    [CmdletBinding()]
    Param (
        
    )
    begin {
        $headers = @{
            Authorization = "$($connection.token_type) $($connection.access_token)"
            ContentType   = "application/json"
        }
        $apiUrl = "https://graph.microsoft.com/v1.0/groups"
    }
    process {
        $SheetData = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
    }
    end {
        return $SheetData
    }
}

#additional variables
$groups = Get-GroupList 
$values = $groups.value
$more = $groups.'@odata.nextLink'

#while loop for paginated results
while ($null -ne $more) {
    $headers = @{
        Authorization = "$($connection.token_type) $($connection.access_token)"
        ContentType   = "application/json"
    }
    $groups2 = Invoke-RestMethod $more -Headers $headers
    $more = $groups2.'@odata.nextLink'
    $values2 = $groups2.value
    $values = $values + $values2
}

#write output to confirm results
Write-Host "Collection Complete"
Write-Host $values.Count "Records Returned"
