
param (
    $startFolder = "F:\" # must have slash at the end
    ,$start = "F:\" # must have slash at the end
    ,$location = 'E:\Logging\Inheritance_Runspaces' # get-location
)
$startSlash = ($start.ToCharArray() | Where-Object { $_ -eq "\" } | Measure-object ).count -1
## ran on \\ewp005491\FileServer
$global:pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
$global:pool.ApartmentState = "MTA"
$global:pool.Open()
$global:runspaces = @()

$scriptblock = {
    param(
        $folder,
        $FolderLVL,
        $location
    )
    function remove-ACE($ACL,$ACE,$folder){
        try{
            Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value "Removing: $($ACE.IdentityReference) From: $($folder)"
            $ACL.RemoveAccessRule($ACE)
            $ACL | Set-Acl $folder
        }catch{
            $ErrorMessage = $_.Exception.Message
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    # corrects inheritanceFlags that are setup incorrect
    function get-inheritance($ACL,$ACE,$folder){
        try{
            if($ACE.InheritanceFlags -ne "ContainerInherit, ObjectInherit" -or $ACE.PropagationFlags -ne 'None'){

                $date = Get-Date -Format "yyyy-MM-dd"
                Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value "no inheritance: $($folder) $($ACE.IdentityReference)"

                $permission = $ACE.IdentityReference, $ACE.FileSystemRights,'ContainerInherit,ObjectInherit', 'None','Allow'
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
                $ACL.SetAccessRule($rule)
                $ACL | Set-Acl $folder
            }
        }catch{
            $ErrorMessage = $_.Exception.Message
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    # this function adds a AD object to NTFS of a folder and subfolders with Full Control
    # this is meant to be for Domain admin and FileServerSecurityAdmin
    function add-admin($ACL, $reference,$folder){
        try{
            $date = Get-Date -Format "yyyy-MM-dd"
            Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value "Add Full Control: $($reference) $($folder)"

            $permission = $reference, 'FullControl','ContainerInherit,ObjectInherit', 'None','Allow'
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
            $ACL.SetAccessRule($rule)
            $ACL | Set-Acl $folder
        }catch{
            $ErrorMessage = $_.Exception.Message
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }

    function get-myacl($folder){
        try{
            # $date = Get-Date -Format "yyyy-MM-dd"
            # Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value "Processing: $($folder)"
            $ACL = get-acl $folder
            return $ACL
        }catch{
            $ErrorMessage = $_.Exception.Message
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    
    $date = Get-Date -Format "yyyy-MM-dd"
    $error_output_path = "$($location)\$($date)_Errors.csv"

    $ACL = get-myacl $folder
    
    $has_FileServSecAdmin = 0
    $has_DomAdmin = 0
    
    # for each access rule do some checks
    foreach ($ACE in $ACL.Access){
        # third level folders must contain FileServerSecurityAdmins & Domain Admins
        # third level folders may have FSG & deleted groups (S-)
        if($FolderLVL -eq 3 -or $FolderLVL -lt 3){
            $IDRef = $ACE.IdentityReference
            
            # check if 3th level folder has PROD\FileServerSecurityAdmins
            if($IDRef -eq 'PROD\FileServerSecurityAdmins'){
                $has_FileServSecAdmin = 1
            }

            # check if 3th level folder has PROD\Domain Admins
            if($IDRef -eq 'PROD\Domain Admins'){
                $has_DomAdmin = 1
            }
            # allowed groups on 3th level folders
            if	($IDRef -like 'PROD\FSG*' -or $IDRef -like 'S-*' -or $IDRef -eq 'PROD\FileServerSecurityAdmins' -or $IDRef -eq 'PROD\Domain Admins' -or $IDRef -eq 'NT AUTHORITY\SYSTEM' -or $IDRef -eq 'BUILTIN\Administrators') { 
                # check if inheritance is set correct
                # if not fix it
                get-inheritance $ACL $ACE $folder
                continue
            }
            ## for local system
            if($IDRef -eq 'PROD\ycreyf'){
                get-inheritance $ACL $ACE $folder
                continue
            }

            # this ACE does not fit the criteria to be a 3th lvl group
            # must be removed
            remove-ACE $ACL $ACE $folder
        }
    }
    # if we did not found FileServerSecurityAdmins or Domain admins in a third level folder then we must add them.
    # we run icacls to reset to reset all rights on n-lvl folders
    
    if($FolderLVL -eq 3){
        if($has_FileServSecAdmin -eq 0){
            # if the 3th level folder does not have FileServerSecurityAdmin then add it
            add-admin $ACL 'PROD\FileServerSecurityAdmins' $folder
        }
        if($has_DomAdmin -eq 0){
            # if the 3th level folder does not have Domain Admin then add it
            add-admin $ACL 'PROD\Domain Admins' $folder
        }
        # reset all rights that are in folders below
        try{
            $date = Get-Date -Format "yyyy-MM-dd"
            Write-Output "ICACLS: $($FolderLVL) $($folder)"
            icacls.exe $folder\* /reset /T /C /L /Q
            # $log = cmd /c "2>&1" icacls.exe $folder\* /reset /T /C /L #/Q
            # add-content -Path "$($location)\$($date)_icalc.log" -Value $log
        }catch{
            $ErrorMessage = $_.Exception.Message
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
        
    }
}

function get-runspace{
    param(
        $scriptblock,
        $folder,
        $folderLVL,
        $location
    )
    $runspace = [PowerShell]::Create()
    $null = $runspace.AddScript($scriptblock)

    $null = $runspace.AddArgument($folder)
    $null = $runspace.AddArgument($folderLVL)
    $null = $runspace.AddArgument($location)

    $runspace.RunspacePool = $global:pool
    $global:runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke(); myname = $folder }

}
function get-folders{
    param(
        $path,
        $startSlash,
        $location
    )
    $listofFolders = [System.IO.Directory]::EnumerateDirectories($path)
    foreach($folder in $listofFolders){
        $FolderLVL = ($folder.ToCharArray() | Where-Object { $_ -eq "\" } | Measure-Object ).count - $startSlash

        if($FolderLVL -gt 3){
            continue
        }

        if($FolderLVL -eq 3){
            Write-Output "Start runspace: $($folder)"
            Get-Runspace $scriptblock $folder $FolderLVL $location
        }

        if($FolderLVL -lt 3){
            get-folders $folder $startSlash $location
        }
    }
}

$scriptName = $MyInvocation.MyCommand.Name
write-warning $scriptName



$Stopwatch = [system.diagnostics.stopwatch]::StartNew()
$startTime = get-date
get-folders $startFolder $startSlash $location
write-warning "All Runspaces added to the pool"
# $global:runspaces.Status -ne $null
$total_runspaces = $global:runspaces.Status.count
while ($null -ne $global:runspaces.Status){
    $completed = $global:runspaces | Where-Object { $_.Status.IsCompleted -eq $true }

    foreach ($runspace in $completed){
        $c++
        $rpName = $runspace.myname
        $results = $runspace.Pipe.EndInvoke($runspace.Status)
        
        try{
            $date = Get-Date -Format "yyyy-MM-dd"
            Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value $results
            $runspace.Status = $null
        }catch{
            $ErrorMessage = $_.Exception.Message
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    if($c -lt 0){continue}
    
    $elapsedTime = $(get-date) - $startTime 
    #do the ratios and "the math" to compute the Estimated Time Of Completion 
    $estimatedTotalSeconds = $total_runspaces / $c * $elapsedTime.TotalSeconds 
    $estimatedTotalSecondsTS = New-TimeSpan -seconds $estimatedTotalSeconds
    $estimatedCompletionTime = $startTime + $estimatedTotalSecondsTS
    
    $diff = New-TimeSpan -Start $startTime -End $estimatedCompletionTime
    Clear-Host
    Write-Output "$($c)/$($total_runspaces) = $($c/$total_runspaces*100)% ETA: $($estimatedCompletionTime) Diff: $($diff)"
    Write-Warning "Completed: $($rpName)"
    if($c -eq $total_runspaces){break}
    Start-Sleep -s 1
}

$global:pool.Close()
$global:pool.Dispose()

$Stopwatch.Stop()
$Stopwatch.Elapsed
