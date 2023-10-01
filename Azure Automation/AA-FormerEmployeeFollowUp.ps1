<#
.SYNOPSIS
This intent behind this script is to ensure that current employees with delegate access to former employees are being 
contacted on a regular basis to ensure they still need access to the email mailbox of former employees. 

.DESCRIPTION
This script runs as an Azure Automation Account, and leverages an App Registration in Azure AD. The permissions required for this
app registration are as follows:
Microsoft Graph - Application Access --> Mail.Send & User.Read.All

This Azure Automation Account will also need the ability to access Exchange Online as a managed identity. 
https://learn.microsoft.com/en-us/azure/automation/enable-managed-identity-for-automation

.FUNCTIONALITY
This script leverages the schedul-ability and automation hosting of Azure Automation Account runbooks to run this script. 

.NOTES
Version 2.0
Published: 1/26/2023
Author: Curtis Smith
#>


#Get Variables from AA Keyvault to get connected
$Client = Get-AutomationVariable -Name 'ClientID'  #Client ID of the App Registration
$secret = Get-AutomationVariable -Name 'Secret'    #Secret from the App Registration
$tenant = Get-AutomationVariable -Name 'TenantId' #Call the Automation Variable for the Tenant ID
$groupID = Get-AutomationVariable -Name 'GroupId'  #call the automation variable for the group ID


#connect to Exchange Online using the managed Identity of the AA account this is running under
Connect-ExchangeOnline -ManagedIdentity -Organization "YOUR-ORG.onmicrosoft.com" #replace this value

#details for connecting via MS Graph
$body =  @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $Client
    Client_Secret = $secret
}
 
$connection = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" -Method POST -Body $body
$token = $connection.access_token


#region Functions
#Function to get the list of termed users
function Get-TermedUsers {
    begin {
        $headers = @{
            Authorization = "$($connection.token_type) $($token)"
            ContentType  = "application/json"
        }
        $apiUrl = "https://graph.microsoft.com/v1.0/groups/$groupID/members"
    }
    process {
        $SheetData = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
    }
    end {
        return $SheetData
    }
}

#Term Template Email Content
$termTemplate = @"
Your Message is Copied here <br>
This message will be the email <br>
Show the source of your existing template to get the HTML code that goes between these lines
"@

#Function for sending a mail message using Graph
#I wrote this function to be standalone, so that it could be reused for sending other emails like the report at the end.
function Send-MailMessage {
    [CmdletBinding()]
    Param (
        [string]$from = "username@domain.com", #This is the email you want the Term Notifications to come from. Can be a person or a DL   
        [Parameter(Mandatory)][string]$subject, #subject fot the email
        [Parameter(Mandatory)][string]$upn, #person who will recieve the email
        [Parameter(Mandatory)]$content
    )
    begin {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }
        $data = @{
            message = @{
                subject = $subject
                body = @{
                    ContentType = "HTML"
                    Content = $content
                }
                toRecipients = @(
                    @{
                        EmailAddress = @{
                            Address = $upn
                        }
                    }
                )
            }          
        }
        $apiUrl = "https://graph.microsoft.com/v1.0/users/$from/sendMail"
    }
    process {
        $json = $data | ConvertTo-Json -Depth 4
        Invoke-RestMethod -Uri $apiURL -Headers $headers -Method POST -Body $json
    }
}


#Calls Function the function to get termed users and saves the content to a variable
$termedUsers = Get-TermedUsers
#Content comes back as a System.Object - Values is where the details about the users are located
$values = $termedUsers.value

#prepare user table for paginated event results
$delegateAccess = New-Object System.Data.DataTable
$delegateAccess.Columns.Add("Termed", "System.String") 
$delegateAccess.Columns.Add("Delegate", "System.String")

#looks up the details about who has delegate access to each termed user accoutn
foreach ($tu in $values) {
    $tu2 = $tu.userPrincipalName
    #Pay special attention to this line, here is where you will need to test to see if there are any service or backup accounts that may be returned with this $m2 variable command, and adjust the filtering so it matches your environment. Just add another {($_.User -notlike "") to this where-object of this next line
	$m2 = Get-EXOMailboxPermission -Identity $tu2 -ErrorAction SilentlyContinue | Where-Object {($_.User -notlike "NT*") -and ($_.AccessRights -eq "FullAccess")} | Select-Object Identity,User
    $delegateCount = $m2 | Measure-Object | Select-Object Count
    
    #some termed user accounts have more than one person with delegate access, so this examines that and ensures that each person with delegate access will get an email
    if ($delegateCount.Count -ge 2 ) {
        foreach($mm in $m2){
            $urow = $delegateAccess.NewRow()
            $urow.termed = $mm.Identity
            $urow.Delegate = $mm.user
            $delegateAccess.Rows.Add($urow)
        }
    }else {
        $urow = $delegateAccess.NewRow()
        $urow.termed = $m2.Identity
        $urow.Delegate = $m2.user
        $delegateAccess.Rows.Add($urow)
    }
}

#Sets a variable to count the number of emails that are sent
$emailSent = 0

#Cycle through the list of termed users and send an email to each manager with delegate access to that mailbox
foreach($term in $delegateAccess){
    $displayname = $term.Termed
    $termSubject = "Former Employee Follow Up - $displayname"
    Send-MailMessage -upn $term.delegate -subject $termSubject -content $termTemplate
    $emailSent += 1
}

#sends the final email report as a message to me so I know how mant emails went out. 
Send-MailMessage -upn "MyEmail@domain.com" -subject "Term Email Report" -content "<h2>Term Follow Up Emails sent: $emailSent</h2>"

#disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
