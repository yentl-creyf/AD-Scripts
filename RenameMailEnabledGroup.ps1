param(
    [string[]]$GroupNames = 'CN=(F) AD HARDENING TEST 3,OU=Groups Functional,OU=PROD,DC=prod,DC=telenet,DC=be',
    [string[]]$NewNames = '(F) AD HARDENING TEST'
)
if ($GroupNames.length -ne $NewNames.length){
    write-warning "Parameters not equal size: GroupNames: $($GroupNames.length) NewNames: $($NewNames.length)";
    break
}
$Hostname="EWP000923.prod.telenet.be"
# Remove sessions if one is left open
Get-PSSession | Remove-PSSession
# create new session
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$Hostname/PowerShell/ -Authentication Kerberos
# import session, this should import commands from exchange server
Import-PsSession $Session -AllowClobber

function get-info($identity){
    $test = Get-ADGroup -Identity $identity -Properties CN,DisplayName,DistinguishedName,mail,proxyAddresses
    write-host "CN: $($test.CN)"
    write-host "Display name: $($test.DisplayName)"
    write-host "DN: $($test.DistinguishedName)"
    write-host "mail: $($test.mail)"
    $test.proxyAddresses | forEach-object { write-host $_}
}

function parse-mail($group,$email=$true){
    $group = $group.replace('(','')
    $group = $group.replace(')','')
    [regex]$pattern = " "
    $group = $pattern.replace($group, "_", 1) 
    $group = $group.replace(' ','.')
    if($email){
        $email = $group + "@telenetgroup.be"
        return $email
    }
    return $group
}
for($i=0;$i -lt $GroupNames.length;$i++){
    get-info($GroupNames[$i])
    $email = parse-mail $NewNames[$i] $true
    $alias = parse-mail $NewNames[$i] $false
    #displayname,cn,mail,mailnickname
    $ManagedBy = 'CN=srvIAM-PROD,OU=Users SYS,OU=PROD,DC=prod,DC=telenet,DC=be'
    Set-ADGroup -Identity $GroupNames[$i] -DisplayName $NewNames[$i] -samaccountname $NewNames[$i] -ManagedBy $ManagedBy
    Set-DistributionGroup -identity $GroupNames[$i] -PrimarySmtpAddress $email 
    Set-DistributionGroup -identity $GroupNames[$i] -alias $alias
    Rename-ADObject -Identity $GroupNames[$i] -NewName $NewNames[$i] #CN
    write-warning "############################"
}
Get-PSSession | Remove-PSSession
