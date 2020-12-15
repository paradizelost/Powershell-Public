$siteurl = "https://demo.teedy.io"
$headers = get-sitelogin
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
<# Uploads files but doesn"t attach to docs. files only visible in the user context of the specific user.
#$toupload =   get-item ".\Advent Of Code Day 1.ps1"
#Invoke-RestMethod -uri "$siteurl/api/file" -Headers $headers -Method PUT -form @{file=$toupload} -ContentType "multipart/form-data"
#>
$taglist = Invoke-RestMethod -uri "$siteurl/api/tag/list" -Headers $headers -Method GET | select-object -ExpandProperty tags
if($taglist){write-host "Got tags"}
$documentlist = Invoke-RestMethod -uri "$siteurl/api/document/list" -Headers $headers -Method GET | select-object -ExpandProperty documents
if($documentlist){write-host "Got docs"}
$filelist = Invoke-RestMethod -uri "$siteurl/api/file/list" -Headers $headers -Method GET |Select-Object -ExpandProperty Files
if($filelist){write-host "Got files"}

$tagtocreate = @{
    name="testapitagcreate$(get-date -format "yyyyMMddssmm")";
    parent="";
    color='#3a87ad'
}
$newtagid = Invoke-RestMethod -uri "$siteurl/api/tag" -Headers $headers -Method PUT -body $tagtocreate -ContentType 'application/x-www-form-urlencoded'
$doctocreate=@{
    title="testDoc";
    language="eng";
}
$newdocid = Invoke-RestMethod -uri "$siteurl/api/document" -Headers $headers -Method PUT -body $doctocreate -ContentType 'application/x-www-form-urlencoded'
$logoutresponse = Invoke-webrequest -Uri "$siteurl/api/user/logout" -Headers $headers -Method POST
if($logoutresponse.BaseResponse.StatusCode -eq 200){
    write-host "logged out successfully"
}
