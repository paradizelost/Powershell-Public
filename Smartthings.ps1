$token="PERSONAL_ACCESS_TOKEN"
$headers=@{
    Authorization = "Bearer $token"
}
$url="https://api.smartthings.com/v1/devices"
$things = (invoke-RestMethod -Method Get -Uri $url -Headers $headers).items
foreach($thing in $things){
    if($thing.components.capabilities.id -contains "switch"){
        write-host $thing.label
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
        if($thing.label -eq "FamilyRoom South East 1"){
            $commandURL = "https://api.smartthings.com/v1/devices/$($thing.deviceid)/commands"
            write-host $commandurl
            do{
                write-host "-----"
                if((get-random -Minimum 0 -Maximum 2)){
                    write-host "ON"
                    invoke-RestMethod -Method POST -Uri $commandURL -Headers $headers -Body $oncommand
                } else {
                    write-host "OFF"
                    invoke-RestMethod -Method POST -Uri $commandURL -Headers $headers -Body $offcommand
                }
            start-sleep 3
            } while($true)
        }
    }
}
