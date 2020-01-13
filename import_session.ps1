
$Hostname="HOSTNAME"
# Remove sessions if one is left open
Get-PSSession | Remove-PSSession
# create new session
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$Hostname/PowerShell/ -Authentication Kerberos
# import session, this should import commands from (exchange) server
Import-PsSession $Session -AllowClobber

#do some stuf


# Cleanup session
Get-PSSession | Remove-PSSession
