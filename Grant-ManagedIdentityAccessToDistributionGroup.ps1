$ManagedIdentityAppId = "[Managed Identity App ID]"
$DistributionGroupName = "App-MailSend-Allowed"
$NoReplyEmailAddress = "no-reply@yourdomain.com" #Address you want the emails to come from
$PolicyScopeGroupId = "App-MailSend-Allowed@yourtenant.onmicrosoft.com"
$ExchangeAdminUser = "[Exchange Admin User Principal Name]"

Connect-ExchangeOnline -UserPricipalName $ExchangeAdminUser

#Create the Distribution Group and add the no-reply email as a member, skip this step if already done
New-DistributionGroup -Name $DistributionGroupName -Type "Security"
Add-DistributionGroupMember -Identity $DistributionGroupName -Member $NoReplyEmailAddress

New-ApplicationAccessPolicy -AppId $ManagedIdentityAppId -PolicyScopeGroupId $PolicyScopeGroupId -AccessRight RestrictAccess -Description "Restrict Managed Identity to send emails only to members of the App-MailSend-Allowed distribution group."

Test-ApplicationAccessPolicy -AppId $ManagedIdentityAppId -Identity $NoReplyEmailAddress #Allowed
Test-ApplicationAccessPolicy -AppId $ManagedIdentityAppId -Identity $ExchangeAdminUser #Denied