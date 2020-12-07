$token="PERSONAL_ACCESS_TOKEN"
$headers=@{
    Authorization = "Bearer $token"
}
$url="https://api.smartthings.com/v1/devices"
$offcommandhash = @{
    "component"="main";
    "capability"="switch";
    "command"="off";
}
$oncommandhash = @{
    "component"="main";
    "capability"="switch";
    "command"="on";
}
$offcommand = "[$($offcommandhash | ConvertTo-Json)]"
$oncommand = "[$($oncommandhash | ConvertTo-Json)]"
$things = (invoke-RestMethod -Method Get -Uri $url -Headers $headers).items
function toggle-lights(){
    param([string]$DeviceLabel)
    foreach($thing in $things){
        if($thing.components.capabilities.id -contains "switch"){
            if($thing.label -eq $DeviceLabel){
                write-host $thing.label
                $lightstatus = (Invoke-RestMethod -Method GET -uri "https://api.smartthings.com/v1/devices/$($thing.deviceid)/status" -headers $headers).components.main.switch.switch.value
                $commandURL = "https://api.smartthings.com/v1/devices/$($thing.deviceid)/commands"
                write-host $commandurl
                    write-host "-----"
                    if(($lightstatus -eq "off")){
                        write-host "ON"
                        invoke-RestMethod -Method POST -Uri $commandURL -Headers $headers -Body $oncommand
                    } else {
                        write-host "OFF"
                        invoke-RestMethod -Method POST -Uri $commandURL -Headers $headers -Body $offcommand
                    }
                    Invoke-RestMethod -Method GET -uri "https://api.smartthings.com/v1/devices/$($thing.deviceid)/status" -headers $headers
            }
        }
    }
}


do{toggle-lights -devicelabel "FamilyRoom South East 1"}while($true)
