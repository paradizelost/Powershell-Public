
function get-sitelogin(){
    $username = read-host "Teedy Username"
    $password = read-host "Teedy Password"
    $tologin=@{username="$username";password="$password";}
    try{
        $loginresponse = Invoke-webrequest -Uri "$siteurl/api/user/login" -Method POST -Body $tologin -SessionVariable Session
    } catch {
        if(($error[0].ErrorDetails.Message|convertfrom-json|select-object -ExpandProperty Type) -eq 'ValidationCodeRequired'){
            $mfacode = read-host "MFA Code Required for user. Please enter MFA Code:"
            if($mfacode -match '\d{6}'){
                $tologin.add('code',$mfacode)
                $loginresponse = Invoke-webrequest -Uri "$siteurl/api/user/login" -Method POST -Body $tologin -SessionVariable Session
            }
        }
    }
    $global:session=$session
    if($loginresponse.baseresponse.StatusCode -eq 200){
        write-host "Logged in successfully"
    }
    $headercookie = $loginresponse.baseresponse.headers.getvalues('Set-Cookie')
    $token,$null = $headercookie -split ";"
    $global:headers=@{
        Cookie = "$token"
    }
    return $global:headers
}
$siteurl = read-host "Teedy URL (i.e. https://demo.teedy.io)"
$global:headers = get-sitelogin
$global:taghash=@{}
function New-Tag(){
    param(
        $TagName,
        $ParentTagName="",
        $color="3a87ad"
    )
    if($tagname.length -gt 36){
        $tagname = $tagname.substring(0,36)
    }
    try{
        if($color -eq "3a87ad"){
            $colorcode="$color"
        } else {
            $colorcode = ("{0:X}" -f [drawing.Color]::FromName($color).toargb()).Substring(2)
        }
    }catch{
        $error[0]
        write-host "Unable to determine color code. Using default blue."
        $colorcode = '3a87ad'
    }
    Update-TagHash
    try{
    if($global:taghash[$TagName]){
        return "TAG $tagname already exists."
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
        name=$TagName  -replace ' ','_' -replace ':','_';
        parent=$parentTagID;
        color="#$colorcode";
    }
    #$mytagtocreate
    $newtagid = Invoke-RestMethod -uri "$siteurl/api/tag" -Headers $global:headers -Method PUT -body $mytagtocreate -ContentType 'application/x-www-form-urlencoded' -WebSession $Session
    Update-TagHash
    } catch {
        $error[0]
    }
    $newtagid.id
}
function Remove-Tag(){
    param(
        [parameter(mandatory)][string]$TagName
    )
    $tagid = $taghash[$tagname].id
    if($tagid){
        $result = Invoke-RestMethod -uri "$siteurl/api/tag/$tagid" -Headers $global:headers -Method DELETE -WebSession $Session
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
        Invoke-RestMethod -uri "$siteurl/api/tag/$tagid" -Headers $global:headers -Method POST -Body $topost -ContentType 'application/x-www-form-urlencoded' -WebSession $Session
    } else {
        write-host "$tagname not found"
    }
}
function Update-TagHash(){
    $uri = [System.UriBuilder]"$siteurl/api/tag/list"
    $taglist = Invoke-RestMethod -uri $uri.uri -Headers $global:headers -Method GET -WebSession $global:session | select-object -ExpandProperty tags 
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
            Invoke-RestMethod -uri "$siteurl/api/file/$file/attach" -Headers $global:headers -Method POST -Body $toattach -ContentType 'application/x-www-form-urlencoded' -WebSession $Session
        }
    }
}
function New-Document(){
    param(
        $title,
        $language='eng',
        $tags,
        $file
    )
    if($file){
        $fileids= Add-File -Files $file
    }
    update-taghash
    $mytags=@()
    foreach($mytag in $tags){
        $mytags += $taghash[$mytag].id
    }
    $title=[System.Web.HttpUtility]::UrlEncode($title)
    $basequery = "title=$title&language=$language"
    if ($tags) { $tagsquery = '&tags={0}' -f ($mytags -join '&tags=') }

    $newdocid = (Invoke-RestMethod -uri "$siteurl/api/document" -Headers $global:headers -Method PUT -body "$($basequery)$($tagsquery)" -ContentType 'application/x-www-form-urlencoded' -WebSession $Session).id
    if($file){
        attach-file -documentid $newdocid -fileid $fileids
    }
    $newdocid
}
Function Add-File(){
    param(
        $Files
    )
    $fileids = @()
    foreach($file in $files){
        if(test-path $file){
            $toupload =   get-item $file
            c:\windows\system32\curl.exe -H "Cookie: $($global:headers['Cookie'])" --url "$siteurl/api/file" --upload-file $toupload.FullName
            $response =curl.exe --location --request PUT 'https://docs.hamik.net/api/file' --header "Cookie: $($global:headers['Cookie'])" --form "file=@`"$($toupload.fullname)`""
            $fileid=($response|convertfrom-json).id
            $fileids += $fileid
            #$fileids += (Invoke-RestMethod -uri "$siteurl/api/file" -Headers $global:headers -Method PUT -form @{$toupload} -ContentType "multipart/form-data").id
        }
    }
    $fileids
}
function Add-Directory(){
    param(
        $AnchorTag='DirUploadTest',
        $Directory='C:\Users\dan\teedytest',
        [switch]$DontUseExistingTags,
        [switch]$OnlyCreateTags,
        $Tags
    )
    Update-TagHash
    if(-not($taghash[$AnchorTag])){
        new-tag -TagName $AnchorTag
    }
    $directories = get-childitem -Path $directory -Directory -Recurse
    $directories+= Get-item -path $directory
    foreach($mydirectory in $directories){
        if($mydirectory.FullName -eq $directory){
            $newtagname=$AnchorTag
        }else{
            $myparts = @(($mydirectory.fullname  -replace [regex]::escape($directory),'').substring(1) -split '\\')
            #$mydirectory.FullName
            #$myparts.count
            for($i=0;$i -lt $myparts.count;$i++){
                $myparts[$i]=$myparts[$i] -replace ' ','_' -replace ':',''
                if(-not($taghash[$myparts[$i]])){
                    if($i -eq 0){
                        write-host "Creating Tag $($myparts[$i])"
                        new-tag -TagName $myparts[$i] -ParentTagName $AnchorTag
                    } else{
                        write-host "Creating Tag $($myparts[$i])"
                        new-tag -TagName $myparts[$i] -ParentTagName $myparts[$i-1]
                    }
                }
            }
            $newtagname = $myparts[-1]
        }
        if(-not $OnlyCreateTags){
            $files = get-childitem -Path $mydirectory.FullName -File | select-object -ExpandProperty FullName 
            if($files.count -gt 0){
                if((split-path $files[0] -parent) -eq $Directory){
                    New-Document -title $mydirectory.FullName -tags @($AnchorTag,$tags) -file $files    
                } else {
                    New-Document -title $mydirectory.FullName -tags @($newtagname,$tags) -file $files
                }
            }
        }
    }
}

$importdir = read-host "Please specify the path to import into Teedy"
$anchortag = read-host "What is the anchor tag to import items under?"
$additionalTags = read-host "Any additional tags (comma separated)?"
$tagstoadd = $additionalTags -split ","
Add-Directory -AnchorTag $anchortag -Directory $importdir -tags $tagstoadd

<#
$documentlist = Invoke-RestMethod -uri "$siteurl/api/document/list" -Headers $global:headers -Method GET | select-object -ExpandProperty documents
if($documentlist){write-host "Got docs"}
$filelist = Invoke-RestMethod -uri "$siteurl/api/file/list" -Headers $global:headers -Method GET |Select-Object -ExpandProperty Files
if($filelist){write-host "Got files"}
#>
$logoutresponse = Invoke-webrequest -Uri "$siteurl/api/user/logout" -Headers $global:headers -Method POST -WebSession $global:session
if($logoutresponse.BaseResponse.StatusCode -eq 200){
    write-host "logged out successfully"
}
