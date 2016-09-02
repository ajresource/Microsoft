param ([string[]]$filename)
Write-Output "" | Out-File -filepath "error.log"

if ($filename -eq $null)
{
Write-Host
Write-Host "CreateUsers -filename filename.csv" -ForegroundColor DarkGreen
Write-Host
exit
}


function create-account ([string]$accountName, [string]$accountDescription,[string]$hostname,[string]$Group,[string]$pasword) {
$comp = [adsi]"WinNT://$hostname"
$user = $comp.Create("User", $accountName)
$user.SetPassword($pasword)
try
{
    $user.SetInfo() 

$user.description = $accountDescription
$user.SetInfo()
$objOU = [ADSI]"WinNT://$hostname/$Group,group"

$objOU.add(“WinNT://$hostname/$accountName”)

}
catch 
{
Write-Output $hostname $accountName| Out-File -append -filepath "error.log"
Write-Output "---------------"| Out-File -append -filepath "error.log"
Write-Output $_ | Out-File -append -filepath "error.log"
}

}


function check-user ([string]$accountName,[string]$hostname)
{
$objComputer = [ADSI]("WinNT://$hostname")
$colUsers = ($objComputer.psbase.children |
    Where-Object {$_.psBase.schemaClassName -eq "User"} |
        Select-Object -expand Name)

   
$blnFound = $colUsers -contains $accountName

return $blnFound

}

function User-Created([string]$accountName, [string]$hostname,[string]$Group){

$UserName = $accountName 
$GroupName = $Group

if ( ((@(([adsi] "WinNT://$hostname/$UserName,user").Groups() | ? { $_.GetType().InvokeMember("Name", "GetProperty", $null, $_, $null) -like $GroupName })).Count 2> $null) -ne 0 ) {
Return 1
}
else {
Return 0
}

}


function Import-Users ([string]$FilePath) {

$Users = Import-Csv $FilePath

ForEach ($item in $Users){ 
  $Username = $($item.Username)
  $Description = $($item.Description)
  $Hostname = $($item.Hostname)
  $Group = $($item.Group)
  $Password = $($item.Password)

  Write-host "Creating user" $Username "..."
  $userStatus = check-user  $Username $Hostname
  If ($userStatus)
    {
    Write-host "username $Username exists, Skipping to the next user..."  -ForegroundColor Yellow
    Write-host
    }
  Else 
    {
    create-account $Username $Description $Hostname $Group $Password
    $userCreated = User-Created $Username  $Hostname $Group
        If ($userCreated -eq 1)
        {
            Write-host "username $Username created and added to group $Group Successfully!! " -ForegroundColor Green
            Write-host
        }
        Else {
            Write-host "Error: Could not create user $Username , please check error log!!! "  -ForegroundColor Red
            Write-host
        }
    }
  

  }
}


Write-host "This script will create local users and add them to a group as per the csv file"  -ForegroundColor DarkGray 
Write-host "CSV File format is as follows" -ForegroundColor DarkGray 
Write-host "Username,Description,Hostname,Group,Password" -ForegroundColor DarkGray 
Write-host "It is recommeded to record the CSV file in the same location of the script" -ForegroundColor DarkGray 
Write-host "You can specify the file details Please Enter CSV File path: Filename.csv" -ForegroundColor DarkGray 
Write-host "---------------------------------------------------------------------------" -ForegroundColor DarkGray 
Write-host "---------------------------------------------------------------------------" -ForegroundColor DarkGray 
Write-host 


Import-Users $filename

Write-host 
Write-host
Write-host "---------------------------------------------------------------------------" -ForegroundColor DarkGray 
Write-host "------------------------End of Script--------------------------------------" -ForegroundColor DarkGray 