Import-Module ServerManager
Import-Module WebAdministration

$ApplicationPath = 'C:\Program Files\Wynyard Group\'
$Cores = Get-ChildItem 'IIS:\Sites\Default Web Site' | Where-Object {$_.Name -like '*Core*'}
$Apps  = Get-ChildItem 'IIS:\Sites\Default Web Site' | Where-Object {$_.Name -notlike '*Core*'}




iisreset /stop

for ($count=0; $count -lt $Cores.Count; $count++){
$path = $Cores[$count].PhysicalPath +'\logs\*.*'
##'Deleting '+$path+'...'
Remove-Item -Path $path


}


for ($appcount=0; $appcount -lt $Apps.Count; $appcount++){
$path1 = 'C:\Program Files\Wynyard Group\'+$Apps[$appcount].Name+'\'+$Apps[$appcount].Name+'AlertDeliveryService\logs\*.*'
$path2 = 'C:\Program Files\Wynyard Group\'+$Apps[$appcount].Name+'\' +$Apps[$appcount].Name+'ERIWindowsService\logs\*.*'
$path3 = 'C:\Program Files\Wynyard Group\'+$Apps[$appcount].Name+'\'+$Apps[$appcount].Name+'LdapSyncService\logs\*.*'
$path4 = 'C:\Program Files\Wynyard Group\'+$Apps[$appcount].Name+'\'+$Apps[$appcount].Name+'PointInTimeService\logs\*.*'
##Remove-Item -Path $path
Remove-Item -Path $path1
Remove-Item -Path $path2
Remove-Item -Path $path3
Remove-Item -Path $path4
}

iisreset /start

