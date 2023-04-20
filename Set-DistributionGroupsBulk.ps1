<#
.SYNOPSIS
This script uses the information obtained by the previous script to use all the relevant Distribution group details, and create 
new groups after they are deleted on prem. 

.DESCRIPTION
The goal is to allow for all distribution groups to be managed in Exchange Online and not need on prem access. Part of moving away from On prem 
Exchange Server is migrating all relevant groups and lists to Exchange Online. There is no native method (that I have found) to do this, so this
script aims to make it easy as possible to migrated all these groups. Details descriptions and breakdowns are located in the links below.

.EXAMPLE
PS C:\> Set-DistributionGroupsBulk.ps1
This is the basics of running the script. There are no additional parameters at this time. 

.OUTPUTS
Various outputs indicated success or an unchanged setting will display on the board. Logging should be included in later versions.

.NOTES
The majority of information regarding this script can be found at the blog post. This provides best explanation of use and expectations
Version: 2.1
Update: 4/11/2023

Version 1.0 can be found at the Part 1 link below. 

.LINK
Part 1 - https://seesmitty.com/how-to-move-distribution-lists-to-exchange-online/
Part 2 - https://seesmitty.com/how-to-move-distribution-lists-to-exchange-online-part-2/
#>

Connect-ExchangeOnline

#path to the back up files
$path = "C:\temp\DLs"
$names = (Get-ChildItem $path).Name


function New-GroupCreation {
    [CmdletBinding()]
    Param (
        [Parameter()]
        [Boolean]$RequireSenderAuthenticationEnabled
    )

    #Define folder paths and gather files and data
    $folder = "$path\$na"
    $Properties = Import-Clixml -Path "$folder\$na.xml"
    $mem = Import-csv "$folder\$na-members.csv"

    #Define variables based on previous group information
    $Name = $Properties.Name
    $Alias = $Properties.Alias
    $Description = $Properties.Description
    $DisplayName = $Properties.DisplayName
    $MemberJoinRestriction = $Properties.MemberJoinRestriction
    $MemberDepartRestriction = $Properties.MemberDepartRestriction
    $members = $mem.PrimarySmtpAddress
    $PrimarySmtpAddress = $Properties.PrimarySmtpAddress
    $LegacyExchangeDN = $Properties.LegacyExchangeDN 
    $RequireSenderAuthenticationEnabled  = $Properties.RequireSenderAuthenticationEnabled 
    $GroupType = "Distribution"

    #Create new DL based on given parameters
    New-DistributionGroup -Alias $alias -Description $Description -DisplayName $DisplayName -MemberDepartRestriction $MemberDepartRestriction -MemberJoinRestriction $MemberJoinRestriction -Members $members -Name $Name -PrimarySmtpAddress $PrimarySmtpAddress -RequireSenderAuthenticationEnabled $RequireSenderAuthenticationEnabled -Type $GroupType
       
    Write-Host "$Name has been created successfully" -ForegroundColor DarkCyan
}

function Set-GroupProperties {


    #Define folder paths and gather files and data
    $folder = "$path\$na"
    $Properties = Import-Clixml -Path "$folder\$na.xml"
    $Name = $Properties.Name
    $managedBy = $Properties.ManagedBy

    #Checks to see whether the group has a managed by field and adds the account(s) running the script if it does not
    if ((($managedBy | Measure-Object).Count) -eq 0) {
        Write-Host "ManagedBy is Blank - Will Be Set to Account Running this Script" -ForegroundColor Yellow
    }elseif ((($managedBy | Measure-Object).Count) -eq 1) {
        Set-DistributionGroup -Identity $Name -ManagedBy $managedBy -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "ManagedBy Configured with $managedBy as the owner" -ForegroundColor Green
    }else {
        foreach ($mb in $managedBy) {
            Set-DistributionGroup -Identity $Name -ManagedBy $mb -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "ManagedBy Configured with $managedBy as the owner" -ForegroundColor Green
        }        
    }

    #Checks to see whether the group has restricted senders and adds them if it does
    if ([string]::IsNullOrEmpty($Properties.AcceptMessagesOnlyFrom)) {
        Write-Host "AcceptMessagesOnlyFrom is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -AcceptMessagesOnlyFrom $Properties.AcceptMessagesOnlyFrom -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "AcceptMessagesOnlyFrom Configured Correctly" -ForegroundColor Green
    }

    #Checks to see whether the group has senders restricted to a specific DL
    if ([string]::IsNullOrEmpty($Properties.AcceptMessagesOnlyFromDLMembers)) {
        Write-Host "AcceptMessagesOnlyFromDLMembers is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -AcceptMessagesOnlyFromDLMembers $Properties.AcceptMessagesOnlyFromDLMembers -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "AcceptMessagesOnlyFromDLMembers Configured Correctly" -ForegroundColor Green
    }
    
    #Determines whether Bcc is blocked for the DL - Default value is none/false
    if ($Properties.BccBlocked -eq $true) {
        Set-DistributionGroup -Identity $Name -BccBlocked $true -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "BccBlocked Configured Correctly" -ForegroundColor Green
    }

    #The BypassModerationFromSendersOrMembers parameter specifies who is allowed to send messages to this moderated recipient without approval from a moderator
    if ([string]::IsNullOrEmpty($Properties.BypassModerationFromSendersOrMembers)) {
        Write-Host "BypassModerationFromSendersOrMembers is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -BypassModerationFromSendersOrMembers $Properties.BypassModerationFromSendersOrMembers -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "BypassModerationFromSendersOrMembers Configured Correctly" -ForegroundColor Green
    }

    #The ByPassNestedModerationEnabled parameter specifies how to handle message approval when a moderated group contains other moderated groups as members.
    if ($Properties.BypassNestedModerationEnabled -eq $true) {
        Set-DistributionGroup -Identity $Name -BypassNestedModerationEnabled $true -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "BypassNestedModerationEnabled Configured Correctly" -ForegroundColor Green

    }

    #CustomAttributes1 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute1)) {
        Write-Host "CustomAttribute1 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute1 $Properties.CustomAttribute1 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute1 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes10 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute10)) {
        Write-Host "CustomAttribute10 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute10 $Properties.CustomAttribute10 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute10 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes11 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute11)) {
        Write-Host "CustomAttribute11 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute11 $Properties.CustomAttribute11 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute11 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes12 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute12)) {
        Write-Host "CustomAttribute12 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute12 $Properties.CustomAttribute12 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute12 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes13 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute13)) {
        Write-Host "CustomAttribute13 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute13 $Properties.CustomAttribute13 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute13 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes14 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute14)) {
        Write-Host "CustomAttribute14 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute14 $Properties.CustomAttribute14 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute14 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes15 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute15)) {
        Write-Host "CustomAttribute15 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute15 $Properties.CustomAttribute15 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute15 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes2 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute2)) {
        Write-Host "CustomAttribute2 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute2 $Properties.CustomAttribute2 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute2 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes3 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute3)) {
        Write-Host "CustomAttribute3 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute3 $Properties.CustomAttribute3 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute3 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes4 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute4)) {
        Write-Host "CustomAttribute4 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute4 $Properties.CustomAttribute4 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute4 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes5 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute5)) {
        Write-Host "CustomAttribute5 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute5 $Properties.CustomAttribute5 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute5 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes6 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute6)) {
        Write-Host "CustomAttribute6 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute6 $Properties.CustomAttribute6 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute6 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes7 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute7)) {
        Write-Host "CustomAttribute7 is Blank" -ForegroundColor Yellow
    }else { 
        Set-DistributionGroup -Identity $Name -CustomAttribute7 $Properties.CustomAttribute7 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute7 Configured Correctly" -ForegroundColor Green

    }

    #CustomAttributes8 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute8)) {
        Write-Host "CustomAttribute8 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute8 $Properties.CustomAttribute8 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute8 Configured Correctly" -ForegroundColor Green
    }

    #CustomAttributes9 Check
    if ([string]::IsNullOrEmpty($Properties.CustomAttribute9)) {
        Write-Host "CustomAttribute9 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -CustomAttribute9 $Properties.CustomAttribute9 -ErrorAction SilentlyContinue
        Write-Host "CustomAttribute9 Configured Correctly" -ForegroundColor Green

    }

    #email addresses - This will add all non-primary smtp addresses as ailases to this mailbox including X500 addresses for Outlook autocomplete support
    foreach($sg in $Properties.EmailAddresses){
        if ($sg -match '^(smtp:|x500:).*') {
            Set-DistributionGroup -Identity $Name -EmailAddresses @{Add=$sg} -ErrorAction SilentlyContinue
            Write-Host "Added $sg successfully" -ForegroundColor Green
        }
    }
    
    #This will add the previous LegacyExchangeDN attribute as a X500 address for Outlook autocomplete support
    if ([string]::IsNullOrEmpty($LegacyExchangeDN)) {
        Set-DistributionGroup -Identity $Name -EmailAddresses @{Add=$LegacyExchangeDN} -ErrorAction SilentlyContinue
        Write-Host "Added LegacyExchangeDN as X500 address successfully" -ForegroundColor Green
    }

    #This parameter specifies a value for the ExtensionCustomAttribute1 property on the recipient.
    if ([string]::IsNullOrEmpty($Properties.ExtensionCustomAttribute1)) {
        Write-Host "ExtensionCustomAttribute1 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -ExtensionCustomAttribute1 $Properties.ExtensionCustomAttribute1 -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "ExtensionCustomAttribute1 Configured Correctly" -ForegroundColor Green
    }

    #This parameter specifies a value for the ExtensionCustomAttribute2 property on the recipient.
    if ([string]::IsNullOrEmpty($Properties.ExtensionCustomAttribute2)) {
        Write-Host "ExtensionCustomAttribute2 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -ExtensionCustomAttribute2 $Properties.ExtensionCustomAttribute2 -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "ExtensionCustomAttribute2 Configured Correctly" -ForegroundColor Green
    }

    #This parameter specifies a value for the ExtensionCustomAttribute3 property on the recipient.
    if ([string]::IsNullOrEmpty($Properties.ExtensionCustomAttribute3)) {
        Write-Host "ExtensionCustomAttribute3 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -ExtensionCustomAttribute3 $Properties.ExtensionCustomAttribute3 -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "ExtensionCustomAttribute3 Configured Correctly" -ForegroundColor Green
    }

   #This parameter specifies a value for the ExtensionCustomAttribute4 property on the recipient.
   if ([string]::IsNullOrEmpty($Properties.ExtensionCustomAttribute4)) {
        Write-Host "ExtensionCustomAttribute4 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -ExtensionCustomAttribute4 $Properties.ExtensionCustomAttribute4 -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "ExtensionCustomAttribute4 Configured Correctly" -ForegroundColor Green
    }

    #This parameter specifies a value for the ExtensionCustomAttribute5 property on the recipient.
    if ([string]::IsNullOrEmpty($Properties.ExtensionCustomAttribute5)) {
        Write-Host "ExtensionCustomAttribute5 is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -ExtensionCustomAttribute5 $Properties.ExtensionCustomAttribute5 -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "ExtensionCustomAttribute5 Configured Correctly" -ForegroundColor Green
    }

    #The GrantSendOnBehalfTo parameter specifies who can send on behalf of this group. 
    if ([string]::IsNullOrEmpty($Properties.GrantSendOnBehalfTo)) {
        Write-Host "GrantSendOnBehalfTo is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -GrantSendOnBehalfTo $Properties.GrantSendOnBehalfTo -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "GrantSendOnBehalfTo Configured Correctly" -ForegroundColor Green
    }
    
    #The HiddenFromAddressListsEnabled parameter specifies whether this recipient is visible in address lists.
    if ($Properties.HiddenFromAddressListsEnabled -eq $true) {
        Set-DistributionGroup -Identity $Name -HiddenFromAddressListsEnabled $true -ErrorAction SilentlyContinue
        Write-Host "HiddenFromAddressListsEnabled Configured Correctly" -ForegroundColor Green
    }

    #The MailTip parameter specifies the custom MailTip text for this recipient. 
    if ([string]::IsNullOrEmpty($Properties.MailTip)) {
        Write-Host "MailTip is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -MailTip $Properties.MailTip -ErrorAction SilentlyContinue
        Write-Host "MailTip Configured Correctly" -ForegroundColor Green
    }

    # The ModeratedBy parameter specifies one or more moderators for this recipient. 
    if ([string]::IsNullOrEmpty($Properties.ModeratedBy)) {
        Write-Host "ModeratedBy is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -ModeratedBy $Properties.ModeratedBy -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "ModeratedBy Configured Correctly" -ForegroundColor Green
    }

    #The ModerationEnabled parameter specifies whether moderation is enabled for this recipient. 
    #The SendModerationNotifications parameter specifies when moderation notification messages are sent
    if ($Properties.SendModerationNotifications -eq $true) {
        Set-DistributionGroup -Identity $Name -ModerationEnabled $true -SendModerationNotifications $Properties.SendModerationNotifications -Confirm:$false -ErrorAction SilentlyContinue
    }

    #The RejectMessagesFrom parameter specifies who isn't allowed to send messages to this recipient. Messages from these senders are rejected.
    if ([string]::IsNullOrEmpty($Properties.RejectMessagesFrom)) {
        Write-Host "RejectMessagesFrom is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -RejectMessagesFrom $Properties.RejectMessagesFrom -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "RejectMessagesFrom Configured Correctly" -ForegroundColor Green
    }

    #The RejectMessagesFromDLMembers parameter specifies who isn't allowed to send messages to this recipient. Messages from these senders are rejected.
    if ([string]::IsNullOrEmpty($Properties.RejectMessagesFromDLMemberss)) {
        Write-Host "RejectMessagesFromDLMembers is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -RejectMessagesFromDLMembers $Properties.RejectMessagesFromDLMembers -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "RejectMessagesFromDLMembers Configured Correctly" -ForegroundColor Green
    }

    <#
    The ReportToManagerEnabled and ReportToOriginatorEnabled parameters affect the return path for messages sent to the group. 
    Some email servers reject messages that don't have a return path. 
    Therefore, you should set one parameter to $false and one to $true, but not both to $false or both to $true.
    #>
    
    #The ReportToManagerEnabled parameter specifies whether delivery status notifications (also known as DSNs, non-delivery reports, NDRs, or bounce messages) are sent to the owners of the group
    if ($Properties.ReportToManagerEnabled -eq $true) {
        Set-DistributionGroup -Identity $Name -ReportToManagerEnabled $true -ReportToOriginatorEnabled $false -Confirm:$false -ErrorAction SilentlyContinue
    }else {
        Set-DistributionGroup -Identity $Name -ReportToManagerEnabled $false -ReportToOriginatorEnabled $true -Confirm:$false -ErrorAction SilentlyContinue
    }

    #The ReportToOriginatorEnabled parameter specifies whether delivery status notifications (also known as DSNs, non-delivery reports, NDRs, or bounce messages) are sent to senders who send messages to this group.
    if ($Properties.ReportToOriginatorEnabled -eq $true) {
        Set-DistributionGroup -Identity $Name -ReportToManagerEnabled $false -ReportToOriginatorEnabled $true -Confirm:$false -ErrorAction SilentlyContinue
    }else{
        Set-DistributionGroup -Identity $Name -ReportToManagerEnabled $true -ReportToOriginatorEnabled $false -Confirm:$false -ErrorAction SilentlyContinue
    }

    #The SendOofMessageToOriginatorEnabled parameter specifies how to handle out of office (OOF) messages for members of the group.
    if ($Properties.SendOofMessageToOriginatorEnabled -eq $true) {
        Set-DistributionGroup -Identity $Name -SendOofMessageToOriginatorEnabled $true -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "SendOofMessageToOriginatorEnabled Configured Correctly" -ForegroundColor Green
    }

    #The SimpleDisplayName parameter is used to display an alternative description of the object when only a limited set of characters is permitted. 
    if ([string]::IsNullOrEmpty($Properties.SimpleDisplayName)) {
        Write-Host "SimpleDisplayName is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -SimpleDisplayName $Properties.SimpleDisplayName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "SimpleDisplayName Configured Correctly" -ForegroundColor Green
    }

    #The WindowsEmailAddress parameter specifies the Windows email address for this recipient. This is a common Active Directory attribute that's present in all environments, including environments without Exchange.
    $WindowsEmailAddress = $Properties.WindowsEmailAddress
    if ([string]::IsNullOrEmpty($WindowsEmailAddress)) {
        Write-Host "WindowsEmailAddress is Blank" -ForegroundColor Yellow
    }else {
        Set-DistributionGroup -Identity $Name -WindowsEmailAddress $WindowsEmailAddress -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "WindowsEmailAddress Configured Correctly" -ForegroundColor Green
    }

    Write-Host "$Name has been updated successfully" -ForegroundColor DarkCyan
} 

function Set-AccessRights {
    $path = "C:\temp\DLs"
    $folder = "$path\$na"

    #test to see if the file exists - apply the users if it does
if (Test-path "$folder\$na-access.csv") {
    $delegates = Import-csv "$folder\$na-access.csv"
}
    foreach($d in $delegates){
        #Assigns delegate access to each person who had it previously
        Add-RecipientPermission -Identity $na -Trustee $d.trustee -AccessRights $d.AccessRights -confirm:$false
    } 

    Write-Host "Delegate rights assigned to $Name successfully" -ForegroundColor DarkCyan

}

#Dynamically create all groups based on the information that was pulled from the last backup
foreach($na in $names){
    New-GroupCreation
    Set-GroupProperties
    Set-AccessRights
}

Disconnect-ExchangeOnline -Confirm:$false
