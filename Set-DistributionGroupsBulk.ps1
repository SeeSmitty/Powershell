#Details about this script located at: https://seesmitty.com/how-to-move-distribution-lists-to-exchange-online/
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
    $Properties = Import-csv "$folder\$na.csv"
    $mem = Import-csv "$folder\$na-members.csv"

    #Define variables based on previous group information
    $Name = $Properties.Name
    $Alias = $Properties.Alias
    $Description = $Properties.Description
    $DisplayName = $Properties.DisplayName
    $Managedby = $Properties.Managedby
    $MemberJoinRestriction = $Properties.MemberJoinRestriction
    $members = $mem.PrimarySmtpAddress
    $PrimarySmtpAddress = $Properties.PrimarySmtpAddress
    $RequireSenderAuthenticationEnabled  = $Properties.RequireSenderAuthenticationEnabled 
    $GroupType = "Distribution"

    #Create new DL based on given parameters
    New-DistributionGroup -Alias $alias -Description $Description -DisplayName $DisplayName -ManagedBy $Managedby -MemberJoinRestriction $MemberJoinRestriction -Members $members -Name $Name -PrimarySmtpAddress $PrimarySmtpAddress -RequireSenderAuthenticationEnabled $RequireSenderAuthenticationEnabled -Type $GroupType
    
    <#
    Commented out but this is where I ran it for my environment - Details on the blog above
    $Group1 = ($Properties.AcceptMessagesOnlyFrom).Split()[0]
    $Group2 = ($Properties.AcceptMessagesOnlyFrom).Split()[1]
    Set-DistributionGroup -Identity $Name -AcceptMessagesOnlyFromDLMembers $Group1, $Group2
    #>
}


#Dynamically create all groups based on the information that was pulled from the last backup
foreach($na in $names){
    New-GroupCreation
}

Disconnect-ExchangeOnline -Confirm:$false
