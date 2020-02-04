param(
    $Groups = 'CN=(C) TIO Security CoE,OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be',# Get-ADGroup -SearchBase "OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be" -Properties extensionAttribute1 -Filter {extensionAttribute1 -Like "*"}
    [ValidateSet('Distribution','Security')]$Cat = 'Distribution',
    [ValidateSet($true,$false)]$whatif = $true
)

#some extra extra assurance
if (-not $whatif){
    $confirmation = Read-Host "Whatif = $($whatif) do you want to continue? (y/n)"
    if($confirmation -ne 'y'){
        write-warning "exiting"
        exit
    }
}

foreach($Group in $Groups){
    $grp = Get-ADGroup -Identity $Group
    $Category = switch($cat){
        'Distribution'  {0}
        'Security'      {1}
    }
    
    if($grp.GroupCategory -ne $Category){
        write-warning "Changing for: [$($Group)] [$($grp.GroupCategory)] to [$($cat)]"
        if($whatif){
            Set-ADGroup -Identity $Group -GroupCategory $Category -WhatIf
        }else{
            Set-ADGroup -Identity $Group -GroupCategory $Category -WhatIf #temp whatif
        }
    }else{
        write-host "[$($Group)] is [$($grp.GroupCategory)]"
    }
}