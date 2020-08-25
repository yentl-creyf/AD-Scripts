param(
    $groups = @('(F) Productie Interventies')
)
# multithreading
$global:pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
$global:pool.ApartmentState = "MTA"
$global:pool.Open()
$global:runspaces = @()

# the script to run in our runspace (thread)
$scriptblock = {
    param(
        $group
    )
    function get-parent($group,$parent_groups,$recursive=$True){
        foreach($parent in $group.memberof){
            if(-Not($parent_groups.contains($parent))){
                # append list
                $parent_groups.Add($parent) > $null
                # lookup parent group
                $parent = Get-ADGroup -identity $parent -Properties MemberOf
                # recursive
                $parent_groups = [System.Collections.ArrayList]@(get-parent $parent $parent_groups)

            }
        }
        return $parent_groups
    }

    # arraylist is faster for appending
    $parent_groups = [System.Collections.ArrayList]@()
    $commands = [System.Collections.ArrayList]@()

    $group_to_clean = Get-ADGroup $group -Properties MemberOf

    # The ArrayList.Add method always returns the index of the new item that you add, so we redirecting the output to $null
    # add group to clean to parent groups
    $parent_groups.Add($group_to_clean.DistinguishedName) > $null
    $parent_groups = [System.Collections.ArrayList]@(get-parent $group_to_clean $parent_groups)


    $nested_users =  Get-ADGroupMember -Identity $group_to_clean -Recursive | where {$_.objectClass -eq "user"} | select DistinguishedName

    # for each parent group, 
    #   add nested user if user is not member of parent group
    foreach($group in $parent_groups){
        $users_in_group = Get-ADGroupMember -Identity $group | where {$_.objectClass -eq "user"} | select DistinguishedName
        foreach($user in $nested_users){
            if(-Not($users_in_group -contains $user)){
                $commands.Add("Add-ADGroupMember -Identity $group -Members $($user.DistinguishedName)") > $null
            }
        }
    }

    # remove direct child groups
    $direct_child_groups = @(Get-ADGroupMember $group_to_clean | where {$_.objectClass -eq "group"} )
    foreach($child in $direct_child_groups){
        $commands.Add("Remove-ADGroupMember -Identity $group_to_clean -Members $child") > $null
    }

    # remove group the groups where group to clean is member of
    foreach($parent in $group_to_clean.memberof){
        $commands.Add("Remove-ADGroupMember -Identity $parent -Members $group_to_clean") > $null
    }

    return $commands
}

# this function starts a runspace
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

# loop over all groups listed
foreach($group in $groups){
    # check if group is valid
    try{
        $group = get-ADGroup -identity $group
    }catch{
        write-warning "[$group] does not exist"
        continue 
    }
    # start a runspace with our script
    Get-Runspace $scriptblock $group
}
$results = [System.Collections.ArrayList]@()
# wait while runespaces are running
while ($runspaces.Status -ne $null){
    $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
    foreach ($runspace in $completed){
        $runspace_name = $runspace.myname
        write-warning "Cleaned: [$runspace_name]"
        $results += $runspace.Pipe.EndInvoke($runspace.Status)
        $runspace.Status = $null
    }
}

# writing output to file
foreach($result in $results){
    $sw = New-Object System.IO.StreamWriter './results.csv', $true
    $sw.WriteLine("$result;")
    $sw.Close()
}
# cleanup runspace pool
$pool.Close()
$pool.Dispose()
