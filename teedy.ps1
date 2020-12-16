$siteurl = "https://demo.teedy.io"
$headers = get-sitelogin
$global:taghash=@{}
function get-sitelogin(){
    $tologin=@{username="demo";password="password";}
    try{
        $loginresponse = Invoke-webrequest -Uri "$siteurl/api/user/login" -Method POST -Body $tologin 
    } catch {
        if(($error[0].ErrorDetails.Message|convertfrom-json|select-object -ExpandProperty Type) -eq 'ValidationCodeRequired'){
            $mfacode = read-host "MFA Code Required for user. Please enter MFA Code:"
            if($mfacode -match '\d{6}'){
                $tologin.add('code',$mfacode)
                $loginresponse = Invoke-webrequest -Uri "$siteurl/api/user/login" -Method POST -Body $tologin 
            }
        }
    }
    if($loginresponse.baseresponse.StatusCode -eq 200){
        write-host "Logged in successfully"
    }
    $headercookie = ($loginresponse|select-object -ExpandProperty Headers)["Set-Cookie"]
    $token,$null = $headercookie -split ";"
    $headers=@{
        Cookie = "$token"
    }
    return $headers
}
function New-Tag(){
    param(
        $TagName,
        $ParentTagName="",
        $color="3a87ad"
    )
    try{
        $colorcode = ("{0:X}" -f [drawing.Color]::FromName($color).toargb() ).Substring(2)
    }catch{
        $error[0]
        write-host "Unable to determine color code. Using default blue."
        $colorcode = '3a87ad'
    }
    Update-TagHash
    if($global:taghash[$TagName]){
        throw "TAG $tagname already exists."
    }
    if((-not($global:taghash[$ParentTagName])) -and ($ParentTagName -ne '') ){
        $parentTagID = (New-Tag -TagName $ParentTagName -ParentTagName '').id
    } else{
        if($ParentTagName -eq ''){
            $parentTagID=''
        } else {
            $parentTagID=$global:taghash[$ParentTagName].id
        }
    }
    $mytagtocreate = @{
        name=$TagName;
        parent=$parentTagID;
        color="#$colorcode";
    }
    $mytagtocreate
    $newtagid = Invoke-RestMethod -uri "$siteurl/api/tag" -Headers $headers -Method PUT -body $mytagtocreate -ContentType 'application/x-www-form-urlencoded'
    Update-TagHash
    $newtagid
}
function Remove-Tag(){
    param(
        [parameter(mandatory)][string]$TagName
    )
    $tagid = $taghash[$tagname].id
    if($tagid){
        $result = Invoke-RestMethod -uri "$siteurl/api/tag/$tagid" -Headers $headers -Method DELETE
        Update-TagHash
    } else {
        $result = "$tagname not found" 
        #continue
    }   
    $result
}
function update-tag(){
    param(
        [parameter(Mandatory)][string]$TagName,
        [parameter()][string]$ParentTagName,
        [parameter()][string]$Color
    )
    update-taghash
    if($taghash[$TagName]){
        $mytag = $taghash[$tagname]
        if($color){
            try{
                $colorcode = ("{0:X}" -f [drawing.Color]::FromName($color).toargb() ).Substring(2)
                $mytag.color = "#$colorcode"
            } catch{
                $error[0]
                write-host "Color $color not found, not changing"
            }
        }
        if($taghash[$ParentTagName]){
            $mytag.parent = $taghash[$ParentTagName].id
        }
        $tagid=$mytag.id
        $mytag
        $topost=@{
            name=$mytag.name;
            id=$mytag.id;
            parent=$mytag.parent;
            color=$mytag.Color
        }
        Invoke-RestMethod -uri "$siteurl/api/tag/$tagid" -Headers $headers -Method POST -Body $topost -ContentType 'application/x-www-form-urlencoded'
    } else {
        write-host "$tagname not found"
    }
}
function Update-TagHash(){
    $taglist = Invoke-RestMethod -uri "$siteurl/api/tag/list" -Headers $headers -Method GET | select-object -ExpandProperty tags
    #if($taglist){write-host "Got tags"}
    $global:taghash=@{}
    foreach($tag in $taglist){
        $global:taghash.add($tag.name, @{ID=$tag.id;Name=$tag.name;Parent=$tag.parent;Color=$tag.color})
        $global:taghash.add($tag.id, @{ID=$tag.id;Name=$tag.name;Parent=$tag.parent;Color=$tag.color})
    }
}
function Attach-File(){
    param(
        $documentID,
        $fileID
    )
    foreach($file in @($fileID)){
        foreach($document in @($documentID)){
            $toattach=@{
                fileID=$file;
                id=$document
            }
            Invoke-RestMethod -uri "$siteurl/api/file/$file/attach" -Headers $headers -Method POST -Body $toattach -ContentType 'application/x-www-form-urlencoded'
        }
    }
}
function New-Document(){
    param(
        $title,
        $language='eng',
        #$tags='',
        $tag='',
        $file
    )
    if($file){
        $fileids= Add-File -Files $file
    }
    $tagid=$taghash[$tag].id
    $doctocreate=@{
        title=$title;
        language="eng";
        tags= $tagid;
    }
    $doctocreate
    $newdocid = (Invoke-RestMethod -uri "$siteurl/api/document" -Headers $headers -Method PUT -body $doctocreate -ContentType 'application/x-www-form-urlencoded').id
    attach-file -documentid $newdocid -fileid $fileids
}
Function Add-File(){
    param(
        $Files
    )
    $fileids = @()
    foreach($file in $files){
        if(test-path $file){
            $toupload =   get-item $file
            $fileids += (Invoke-RestMethod -uri "$siteurl/api/file" -Headers $headers -Method PUT -form @{file=$toupload} -ContentType "multipart/form-data").id
        }
    }
    $fileids
}
$documentlist = Invoke-RestMethod -uri "$siteurl/api/document/list" -Headers $headers -Method GET | select-object -ExpandProperty documents
if($documentlist){write-host "Got docs"}
$filelist = Invoke-RestMethod -uri "$siteurl/api/file/list" -Headers $headers -Method GET |Select-Object -ExpandProperty Files
if($filelist){write-host "Got files"}
$logoutresponse = Invoke-webrequest -Uri "$siteurl/api/user/logout" -Headers $headers -Method POST
if($logoutresponse.BaseResponse.StatusCode -eq 200){
    write-host "logged out successfully"
}
