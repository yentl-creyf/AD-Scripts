param(
    $folders = @('C:\Users\ycreyf\Desktop\testing'),
    $ADobject = 'PROD\Domain Admins',
    [ValidateSet('ReadAndExecute','Modify','FullControl')]$Grant='ReadAndExecute'
)
function add-permission($acl,$folder,$grant,$ADobject){
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$ADobject", "$Grant", "ContainerInherit, ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl $folder $acl
}
foreach ($folder in $folders) {
    $acl = Get-Acl $folder
    add-permission $acl $folder $grant $ADobject
}
