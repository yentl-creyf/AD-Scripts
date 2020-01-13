## run on oim-rm.prd.corp.telenet.be
Param(
    [string]$Group
)

function get-isunicode($string){
    #write-host 'Checking unicode'
    if($string -match '[^\u0000-\u007F]+'){
        Write-Warning "$($string) is Not ASCII"
        return $False
    }else {
        return $True
    }
}
function get-cleanName($string){
    #write-host 'Cleaning string'
    $string = $string.Trim()
    $string=$string.replace('&',' and ')
    $string=$string.replace('  ',' ')
    return $string
}
function get-groupName($Group_Name){
    write-host "input: $Group_Name"
    if(-Not $Group_Name){$Group_Name = read-host "Enter Group Name"}
    $Group_Name = get-cleanName($Group_Name)
    if (-Not (get-isunicode($Group_Name))){
        get-groupName('')
    }else{
        return $Group_Name
    }
}
function get-Newgroup($Group){
    $Group_Name=get-groupName($Group)

    #should be read from a config file
    $Group_Scope = switch -Wildcard ($Group_Name){
        '(D)*'      {2} #Universal
        '(C)*'      {2} #Universal
        '(F)*'      {2} #Universal
        '(A)*'      {1} #Global
        '(ASG)*'    {1} #Global
        default     {1} #Global
    }
    #should be read from a config file
    $Group_Path = switch -Wildcard ($Group_Name){
        '(A)*'      {"OU=Groups TIM Application Entitlements,OU=PROD,DC=prod,DC=telenet,DC=be"}
        '(ASG)*'    {"OU=Applications,DC=prod,DC=telenet,DC=be"}
        '(D)*'      {"OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be"}
        '(C)*'      {"OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be"}
        '(F)*'      {"OU=Groups Functional,OU=PROD,DC=prod,DC=telenet,DC=be"}
        default     {write-warning "No valid path(OU) found for $($Group_Name), please use the correct prefix"}
    }

    if(-Not $Group_Path){get-Newgroup;break}
    try{$result = get-ADGroup -Identity $Group_Name }catch{write-warning 'Creating new group'}
    if($result){write-warning 'Group already exists';get-Newgroup;break}

    write-host "New-ADGroup -Name $Group_Name -Path $Group_Path -GroupScope $Group_Scope -whatif"
    New-ADGroup -Name $Group_Name -Path $Group_Path -GroupScope $Group_Scope -whatif
}

get-Newgroup($group)
