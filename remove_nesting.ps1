param(
    [System.Collections.ArrayList]$groups = '(F) Productie Interventies'
)

$global:pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
$global:pool.ApartmentState = "MTA"
$global:pool.Open()
$global:runspaces = @()

$scriptblock = {
    param(
        $group
    )
    $commands = [System.Collections.ArrayList]@()
    $users =  Get-ADGroupMember -Identity $group -Recursive | select DistinguishedName
    $users_in_group = Get-ADGroupMember -Identity $group | where {$_.objectClass -eq "user"} | select DistinguishedName
    # add user to group if user is not in the group
    foreach($user in $users){ 
        # if user is already in the group do nothing
        if($users_in_group -contains $user){
            $commands += "# $user is already in $group"
            continue
        }
        $commands +="Add-ADGroupMember -Identity $group -Members $($user.DistinguishedName)"
    }
    $nested_groups = @(Get-ADGroupMember $group | where {$_.objectClass -eq "group"} )
    foreach($nested_group in $nested_groups){
        $commands += "Remove-ADGroupMember -Identity $group -Members $nested_group"
    }
    return $commands
}

function get-runspace{
    param(
        $scriptblock,
        $group
    )
    $runspace = [PowerShell]::Create()
    $null = $runspace.AddScript($scriptblock)

    $null = $runspace.AddArgument($group)

    $runspace.RunspacePool = $global:pool
    $global:runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke(); myname = $group }

}

foreach($group in $groups){
    # check if group is valid
    try{
        $group = get-ADGroup -identity $group
    }catch{
        write-warning "[$group] does not exist"
        continue 
    }
    Get-Runspace $scriptblock $group
}
$results = [System.Collections.ArrayList]@()
while ($runspaces.Status -ne $null){
    $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
    foreach ($runspace in $completed){
        $runspace_name = $runspace.myname
        write-warning "Cleaned: [$runspace_name]"
        $results += $runspace.Pipe.EndInvoke($runspace.Status)
        $runspace.Status = $null
    }
}

foreach($result in $results){
    $sw = New-Object System.IO.StreamWriter './results.csv', $true
    $sw.WriteLine("$result;")
    $sw.Close()
}

$pool.Close()
$pool.Dispose()


