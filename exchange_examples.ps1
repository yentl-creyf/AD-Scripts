# Module:
# exchange
# https://docs.microsoft.com/en-us/powershell/module/exchange/users-and-groups/set-distributiongroup?view=exchange-ps

$group= "Group DN"
$email = "<prefix>_<text.with.replace.space.by.dot>@<domain>.<com/be/etc>"
$remove_mail = "<prefix>_<text.with.replace.space.by.dot>@<domain>.<com/be/etc>"
$alias = "<prefix>_<text.with.replace.space.by.dot>"

#commands
Set-DistributionGroup -identity $group  -PrimarySmtpAddress $email 
Set-DistributionGroup -identity $group  -emailaddresses @{Remove=$remove_mail}
Set-DistributionGroup -identity $group  -emailaddresses @{Add=$email}
Set-DistributionGroup -identity $group  -alias $alias # mail nickname in AD

# disable all groups in the Groups Departement OU that have no extensionAttribute1
$Groups = Get-ADGroup -SearchBase "OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be" -Filter {extensionAttribute1 -NotLike "*"}
foreach ($Group in $Groups) {
    write-host "Disable-DistributionGroup: $($Group.Name)"
    Disable-DistributionGroup -identity "$Group" -confirm:$false
}
