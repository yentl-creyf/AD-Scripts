param(
    $Groups = 'CN=(F) AD Security Hardening Test Group,OU=Groups Functional,OU=PROD,DC=prod,DC=telenet,DC=be',
    [ValidateSet('DomainLocal','Global','Universal')]$ScopeName='Universal'
)

foreach($Group in $Groups){
    $AD_Group = Get-ADGroup -Identity $Group
    $Scope = switch($ScopeName){
        'DomainLocal'   {0}
        'Global'        {1}
        'Universal'     {2}
    }

    if($AD_Group.GroupScope -ne $Scope){
        write-warning "Changing for: [$($Group)] [$($AD_Group.GroupScope)] to [$($ScopeName)]"
        Set-ADGroup -Identity $Group -GroupScope $Scope
    }else{
        write-host "[$($Group)] is [$($AD_Group.GroupScope)]"
    }
}
