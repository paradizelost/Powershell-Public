<#   
.SYNOPSIS   
    This script was started due to the tendency of programs to crash when managing simple RDP connections
    And not being able to store creds. This will auto-type them for you.
.PARAMETER CSVPath
    Path to the CSV file with the following column headers:
    ServerName,IPAddress,Port,LogonDomain,LogonUserID,ScreenSize,Console,RestrictedAdmin,Width,Height,Span,MultiMon,Prompt,Gateway
.NOTES   
	Name: Manage-RDPConnection.ps1
	Author: Dan Hamik 
	Contact: Email - danhamik@gmail.com
	DateCreated: 2018-03-23
    Version: 1.0
.EXAMPLE 	
    TO DO
#>
[cmdletbinding(SupportsShouldProcess, ConfirmImpact = 'high')]
param(
    [parameter()][string]$CSVPath="$env:USERPROFILE\Documents\RDPConnections.csv",
    [parameter()][switch]$Edit
)
Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  public class WinAp {
     [DllImport("user32.dll")]
     [return: MarshalAs(UnmanagedType.Bool)]
     public static extern bool SetForegroundWindow(IntPtr hWnd);

     [DllImport("user32.dll")]
     [return: MarshalAs(UnmanagedType.Bool)]
     public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  }

"@ -ErrorAction SilentlyContinue
$headers = @("ServerName", "GroupName", "IPAddress", "Port", "LogonDomain", "LogonUserID", "ScreenSize", "Console", "Width", "Height", "Span", "MultiMon", "Gateway")
$creds = @{}
function Global:connect-server(){
    param(
        [parameter(Mandatory)][int]$ServerInfo
    )
    $myserver = $Global:RDPList[$ServerInfo]
    $credinfo = "$($myserver.LogonDomain)\$($myserver.logonuserid)"
    if ($creds["$credinfo"]) {
        $cred = $creds["$credinfo"]
    } else {
        $creds["$credinfo"] = Get-Credential
        $cred = $creds["$credinfo"]
    }
    $process = start-process mstsc.exe -ArgumentList "/v:$($myserver.ServerName) /public" -PassThru
    [void][WinAP]::SetForegroundWindow($process.MainWindowHandle)
    [void][Winap]::ShowWindow($process.MainWindowHandle, 5)
    [void][Winap]::ShowWindow($process.MainWindowHandle, 5)
    start-sleep 2
    #write-output $cred.getnetworkcredential().password
    [System.Windows.Forms.SendKeys]::SendWait("$($cred.username){TAB}")
    start-sleep .5
    [System.Windows.Forms.SendKeys]::SendWait("$($cred.getnetworkcredential().password){enter}")
}
function Show-Form() {
    Add-Type -AssemblyName System.Windows.Forms
    $form = New-Object Windows.Forms.Form
    #$form.Size = New-Object Drawing.Size @(200, 100)
    $form.StartPosition = "CenterScreen"
    $form.AutoSize = $true
    $form.AutoScroll=$false
    $form.VerticalScroll.Visible=$false
    $maintable = New-Object System.Windows.Forms.TableLayoutPanel
    $maintable.Dock = [System.Windows.Forms.DockStyle]::Top
    $maintable.autosize = $true
    $maintable.CellBorderStyle = "Inset"
    $maintable.VerticalScroll.Visible=$true
    $maintable.AutoScroll=$true
    $form.controls.add($maintable)
    #$maintable.VerticalScroll.Visible=$true
    $gb = @{}
    $gbindex=0
    $gt = @{}
    $index=0
    foreach ($groupname in ($Global:RDPList|Select-Object -property GroupName -Unique).groupname) {
        if ($groupname -eq "") {
            $groupname = "NONE"
        }
        $mygb = new-object Windows.Forms.GroupBox
        $mygt = New-Object System.Windows.Forms.TableLayoutPanel
        $mygb.dock = 'left'
        $mygt.dock='fill'
        $mygb.autosize = $true
        $mygt.autosize = $true
        $mygt.CellBorderStyle = "Inset"
        $mygb.text = $groupname
        $mygb.Controls.add($mygt)
        $gb.add($groupname, $mygb)
        $gt.add($groupname, $mygt)
        $maintable.controls.add($mygb, $gbindex, $index)
        
        if ($gbindex -eq 1) {$gbindex = 0; $index++}else {$gbindex++}
    }
    
    $GroupColumn = @{}
    $GroupRow =  @{}
        for ($i = 0; $i -le ($Global:RDPList.count - 1) ; $i++) {
            $servername = $Global:RDPList[$i].ServerName
            write-verbose "Working on $servername"
            $btn = New-Object System.Windows.Forms.Button
            $btn.Text = $servername
            $btn.AutoSize = $true
            $btn.anchor='left','right'
            $btn.add_click( { & connect-server -ServerInfo $i  }.GetNewClosure() )
            $groupname = $Global:RDPList[$i].GroupName
            write-verbose $groupname
            if(([string]::IsNullOrEmpty($GroupColumn["$groupname"]))){
                $GroupColumn["$groupname"]=0
            } 
            if(([string]::IsNullOrEmpty($GroupRow["$groupname"]))){
                $GroupRow["$groupname"]=0
            }
            write-verbose "$($GroupRow["$groupname"]) $($GroupColumn["$groupname"])"
            write-verbose $btn.size
            $gt["$groupname"].Controls.Add($btn,$GroupColumn["$groupname"],$GroupRow["$groupname"])
            if ($GroupColumn["$groupname"] -eq 2) {$GroupColumn["$groupname"] = 0; $GroupRow["$groupname"]++} else { $GroupColumn["$groupname"]++}
        }
    $form.width = $maintable.Width
    $drc = $form.ShowDialog()
}
function add-server() {
    #$newRow = new-object psobject -property @{        ServerName = (read-host "SERVERNAME")  ; LogonDomain = (read-host "DOMAINNAME"); GroupName = (Read-Host "GroupName")}
    $newrow =""
    foreach ($header in $headers){
        $newrow = $newrow + "`"$(read-host "$($header.toupper())")`","
    }
    add-content -path $csvpath -value $newrow
    update-rdplist
    $Global:RDPList | sort-object -property ServerName |Export-Csv -Path $CSVPATH -NoTypeInformation
    
    #$Global:RDPList | sort-object -property ServerName |Export-Csv -Path $CSVPATH -NoTypeInformation
    #$Global:RDPList = @($global:rdplist | sort-object -property ServerName)
}
function update-rdplist(){
    $Global:RDPList = @(get-content -path $Global:CSVPath | select-object -skip 1 | convertfrom-csv  -header $headers | sort-object -property ServerName) 
    #$global:RDPList = @($global:RDPList | sort-object -property ServerName)
}
function show-servers(){
    foreach($index in 0 .. ($Global:RDPList.count-1)){
        write-output "$($index +1) - $($Global:RDPList[$index].ServerName)"
    }
}

function remove-server() {
    show-servers
    $toremove = read-host "Which server would you like to remove?"
    $newcsv = @()
    foreach ($index in 0 .. ($Global:RDPList.count - 1)) {
        if ($index -ne ($toremove - 1)) {
            $newcsv += $Global:RDPList[$index]
        }
    }
    if ($newcsv.count -gt 0) {
        $newcsv| sort-object -property ServerName |Export-Csv -Path $CSVPATH -NoTypeInformation 
    }
    else {
        set-content -path $CSVPath -Value "`"ServerName`",`"GroupName`",`"IPAddress`",`"Port`",`"LogonDomain`",`"LogonUserID`",`"ScreenSize`",`"Console`",`"Width`",`"Height`",`"Span`",`"MultiMon`",`"Gateway`""
    }

    update-rdplist
}
function show-menu() {
    param(
        [string]$Title = "-=-=-=-=-=-=-=-Main Menu-=-=-=-=-=-=-=-"
    )
    $menu = @"
$title
1: Show Server List
2: Add Server to List
3: Remove Server from List
Q: Quit
"@

    write-output $menu
}
$Global:CSVPath = $CSVPath
if (-not(test-path $CSVPath)) {
    $edit=$true
    new-item $CSVPath
    set-content -path $CSVPath -Value "`"ServerName`",`"GroupName`",`"IPAddress`",`"Port`",`"LogonDomain`",`"LogonUserID`",`"ScreenSize`",`"Console`",`"Width`",`"Height`",`"Span`",`"MultiMon`",`"Gateway`""
} elseif ( (get-content $CSVPath) -eq "") {
    $edit=$true
    set-content -path $CSVPath -Value "`"ServerName`",`"GroupName`",`"IPAddress`",`"Port`",`"LogonDomain`",`"LogonUserID`",`"ScreenSize`",`"Console`",`"Width`",`"Height`",`"Span`",`"MultiMon`",`"Gateway`""
}

update-rdplist
if ($edit) {
    if ($Global:RDPList.count -eq 0) {
        $addserver = read-host ("No servers found, do you want to add a server? Y/N")
        if ($addserver -eq "Y") {
            add-server
        }
    }
    else {
        do {
            Show-Menu
            $input = Read-Host "Please make a selection"
            switch ($input) {
                '1' {
                    cls
                    show-servers
                } '2' {
                    cls
                    add-server
                } '3' {
                    cls
                    remove-server
                } 'q' {
                    return
                }
            }
        }
        until ($input -eq 'q')
    }
}
else {
    Show-Form
}