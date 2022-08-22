#Variables
$thumb = {"thumbprint"}
$client = {"clientID"}
$tenant = {"tenantID"}
$org = {"PrimaryDomain"}
$Certificate = Get-ChildItem Cert:\CurrentUser\My\$thumb
$GroupName = "Group Name" #Display Name of the group where termed users exist
$group = Get-MgGroup -Filter "DisplayName eq '$GroupName'" | select Id

#connection Strings
Connect-ExchangeOnline -CertificateThumbPrint $thumb -AppID $client -Organization $org
Connect-Graph -TenantId $tenant -AppId $client -Certificate $Certificate


#region functions
function Send-TermMail {
    $to = $active
    $from = "from@noreplydomain.com"
    $bcc = "bcc@noreplydomain.com"
    $subject = "Termed Employee - " + $term.DisplayName
    $type = "html"
    $template = Get-Content -path "C:\temp\Template.html" -raw

    $params = @{
	    Message = @{
		    Subject = $subject
		    Body = @{
			    ContentType = $type
			    Content = $template
		    }
		    ToRecipients = @(
			    @{
				    EmailAddress = @{
					    Address = $to
				    }
			    }
		    )
		    BccRecipients = @(
			    @{
				    EmailAddress = @{
					    Address = $bcc
				    }
			    }
		    )
	    }
	    SaveToSentItems = "true"
    }  

Send-MgUserMail -UserId $from -BodyParameter $params
}

function Get-DelegateAccess {
	#Function is used to get the members of the termed users group
	$termedUsers = Get-MgGroupMember -GroupId $group.Id #gets the members of the Termed Users group
	$delegateAccess = @()
	foreach ($tu in $termedUsers) {
		$tu2 = Get-MgUser -UserId $tu.id | select UserPrincipalName
		$m2 = Get-EXOMailboxPermission -Identity $tu2.userPrincipalName | Where-Object {($_.User -notlike "NT*") -and ($_.AccessRights -eq "FullAccess")} | select Identity,User
		$delegateAccess += $m2
	}
}

function Send-FollowUp {
    foreach($person in $delegateAccess){
        $term = Get-EXOMailbox -Identity $person.identity | select DisplayName,userPrincipalName #former employee
        $active = $person.user #manager with delgate access
        Send-TermMail
    }  
}

#endregion functions

#gather Delegate access details
Get-DelegateAccess

#Send the follow up email to the appropriate people
Send-FollowUp

Disconnect-ExchangeOnline -Confirm:$false
Disconnect-Graph
