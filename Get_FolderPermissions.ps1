Param(
    $startFolder = '\\prod451\PRD\DEP\',# must have slash at the end, location where the script needs to start reading
    $start = '\\prod451\PRD\DEP\', # must have slash at the end, location what is considered the 0th folder
    $location = '\\vnfs01.prd.corp.Telenet.be\tpwlsoim\fileshareaccess', # location of output
    $maxfolderlvl = 6
)
$startSlash = ($start.ToCharArray() | Where-Object { $_ -eq "\" } | Measure-object ).count -1
## ran on \\ewp005491\FileServer
function get-data {
    param(
        $folder,
        $FolderLVL,
        $location
    )
    # this function gets the Access Control List of a folder (ACL)
    function get-myacl($folder){
        try{
            $ACL = get-acl $folder
            return $ACL
        }catch{
            $ErrorMessage = $_.Exception.Message
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    # this functions writes the ACL to file
    function write-ACL($ACL){
        try{
            # start new streamwriter, with append true
            $sw = New-Object System.IO.StreamWriter "$($location)\$($date)_FolderPerm.csv",$true
            # loop over access rules in ACL
            foreach($ACE in $ACL.Access){
                # skip over folders greater then niveau 3 that have inherited permissions
                if($FolderLVL -gt 3 -and $ACE.IsInherited -eq $true){continue}
                # write to file
                $sw.WriteLine("$($folder);$($ACE.IdentityReference);$($FolderLVL);$($ACE.IsInherited)")
            }
            # close stream writer
            $sw.Close()
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
    write-ACL $ACL
    
}
# loop over the folders we need
function get-folders{
    param(
        $path,
        $startSlash,
        $location,
        $maxfolderlvl
    )
    $listofFolders = [System.IO.Directory]::EnumerateDirectories($path)
    foreach($folder in $listofFolders){
        $FolderLVL = ($folder.ToCharArray() | Where-Object { $_ -eq "\" } | Measure-Object ).count - $startSlash
        # we are not interested in folder with a niveau greater then this niveau
        if($FolderLVL -gt $maxfolderlvl){continue}
        # create a runspace with the folder to collect data
        if($FolderLVL -eq $maxfolderlvl -or $FolderLVL -lt $maxfolderlvl){
            # Write-Output "Reading: $($folder)"
            Get-data $folder $FolderLVL $location
        }
        # loop to next folder if current folder niveau is less then our max folder niveau
        if($FolderLVL -lt $maxfolderlvl){
            get-folders $folder $startSlash $location $maxfolderlvl
        }
    }
}

$date = Get-Date -Format "yyyy-MM-dd"
$error_output_path = "$($location)\$($date)_Errors.csv"

$Stopwatch = [system.diagnostics.stopwatch]::StartNew()
# main function, looping over folders, starting runspaces
get-folders $startFolder $startSlash $location $maxfolderlvl

$Stopwatch.Stop()
$Stopwatch.Elapsed
