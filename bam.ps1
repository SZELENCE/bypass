Clear-Host

if ((Get-AuthenticodeSignature $MyInvocation.MyCommand.Path).Status -ne "Valid")
{
	
	$check = [System.Windows.Forms.MessageBox]::Show($this, "WARNING:`n$(Split-path $MyInvocation.MyCommand.Path -Leaf) has been modified since it was signed.`nPress 'YES' to Continue or 'No' to Exit", "Warning", 'YESNO', 48)
	switch ($check)
	{
		"YES"{ Continue }
		"NO"{ Exit }
	}
}
$sw = [Diagnostics.Stopwatch]::StartNew()

if (!(Get-PSDrive -Name HKLM -PSProvider Registry)){
    Try{New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE}
    Catch{"Error Mounting HKEY_Local_Machine"}
}
$bv = ("bam", "bam\State")
Try{$Users = foreach($ii in $bv){Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($ii)\UserSettings\" | Select-Object -ExpandProperty PSChildName}}
Catch{
    "Error Parsing BAM Key. Likely unsupported Windows Version"
    exit
}
$rpath = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\","HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\")

$UserTime = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation").TimeZoneKeyName
$UserBias = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation").ActiveTimeBias
$UserDay = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation").DaylightBias


$Bam = Foreach ($Sid in $Users){$u++
            
        foreach($rp in $rpath){
           Write-Progress -id 1 -Activity "$($rp)"
           $BamItems = Get-Item -Path "$($rp)UserSettings\$Sid" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property
           Write-Progress -id 2 -Activity "Collecting Security ID (sid) entries" -Status "($($Users.Count)) sid: $($objSID.value)" -ParentId 1 
           $bi = 0 
	    
            Try{
            $objSID = New-Object System.Security.Principal.SecurityIdentifier($Sid)
            $User = $objSID.Translate( [System.Security.Principal.NTAccount]) 
            $User = $User.Value
            }
            Catch{$User=""}
            $i=0
            ForEach ($Item in $BamItems){$i++
		    $Key = Get-ItemProperty -Path "$($rp)UserSettings\$Sid" -ErrorAction SilentlyContinue| Select-Object -ExpandProperty $Item
            Write-Progress -id 3 -Activity "Collecting BAM entries for SID: $($objSID.value)" -Status "(Entry $i of $($BamItems.Count))"  -ParentId 1 
	
            If($key.length -eq 24){
                $Hex=[System.BitConverter]::ToString($key[7..0]) -replace "-",""
                $TimeLocal = Get-Date ([DateTime]::FromFileTime([Convert]::ToInt64($Hex, 16))) -Format o
			    $TimeUTC = Get-Date ([DateTime]::FromFileTimeUtc([Convert]::ToInt64($Hex, 16))) -Format u
			    $Bias = -([convert]::ToInt32([Convert]::ToString($UserBias,2),2))
			    $Day = -([convert]::ToInt32([Convert]::ToString($UserDay,2),2)) 
			    $Biasd = $Bias/60
			    $Dayd = $Day/60
			    $TImeUser = (Get-Date ([DateTime]::FromFileTimeUtc([Convert]::ToInt64($Hex, 16))).addminutes($Bias) -Format s) 
			    $d = if((((split-path -path $item) | ConvertFrom-String -Delimiter "\\").P3)-match '\d{1}')
			    {((split-path -path $item).Remove(23)).trimstart("\Device\HarddiskVolume")} else {$d = ""}
			    $f = if((((split-path -path $item) | ConvertFrom-String -Delimiter "\\").P3)-match '\d{1}')
			    {Split-path -leaf ($item).TrimStart()} else {$item}	
			    $cp = if((((split-path -path $item) | ConvertFrom-String -Delimiter "\\").P3)-match '\d{1}')
			    {($item).Remove(1,23)} else {$cp = ""}
			    $path = if((((split-path -path $item) | ConvertFrom-String -Delimiter "\\").P3)-match '\d{1}')
			    {"(Vol"+$d+") "+$cp} else {$path = ""}			
			
                [PSCustomObject]@{
                            'Examiner Time' = $TimeLocal
						    'Last Execution Time (UTC)'= $TimeUTC
						    'Last Execution User Time' = $TimeUser
						     Application = 	$f
						     Path =  		$path
						     User =         $User
						     Sid =          $Sid
                             rpath =        $rp
                             }}}}
                 }
             
           

$Bam|Out-GridView -PassThru -Title "BAM key entries $($Bam.count)  - User TimeZone: ($UserTime) -> ActiveBias: ( $Bias) - DayLightTime: ($Day)"

$sw.stop()
$t=$sw.Elapsed.TotalMinutes
write-host "Elapsed Time $t minutes" -f yellow
