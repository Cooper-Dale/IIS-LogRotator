clear
$tool_version = "2"
# by Cooper

$IIS_log_path = "C:\Windows\System32\LogFiles\HTTPERR\" #lomítko na konci NUTNÉ
$IIS_outdir = "M:\weby\Dropbox\old"
$reg_basepath = "HKLM:\Software\BSS\IIS_ERROR_logrotator"
$file_filter = "*.log"


IF(!(Test-Path $reg_basepath)) { New-Item -Path $reg_basepath -Force | Out-Null }
New-ItemProperty -Path $reg_basepath -Name version -Value $tool_version -PropertyType DWord -Force | Out-Null

function fNewfile {
	$global:reg_instancepath = $reg_basepath 
	$file_old = (Get-ItemProperty -Path $reg_instancepath -Name LastFile -ErrorAction SilentlyContinue).LastFile

	$latest = (Get-ChildItem -Path $IIS_log_path -Filter $file_filter | Sort-Object CreationTime -Descending | Select-Object -First 1).name
	Write-Host "old file" $file_old "new-file" $latest
	IF(!(Test-Path $reg_instancepath)) { New-Item -Path $reg_instancepath -Force | Out-Null }
	New-ItemProperty -Path $reg_instancepath -Name LastFile -Value $latest -PropertyType STRING -Force | Out-Null
	
	IF (!$file_old ) { 
		#Write-Host "nic v registru"
		}
	elseif ($file_old -ne $latest ) {
		Write-Host "v regu je starý soubor, tak se na něj ještě jednou podívám" $file_old "vs" $latest
		$latest = $file_old
		}
	else {
		#Write-Host "vše OK"
		}
	
	$global:IISfile = $IIS_log_path + "\" + $latest
	#Write-Host $IISfile
	
	#output
	$global:IISoutfile = $IIS_outdir + "\IIS_Err_" + $env:computername + "_" + $(Get-Date -format "yyMMdd-HHmmss") + ".log"
	}

function Counting
	{
	$global:lines_old = (Get-ItemProperty -Path $reg_instancepath -Name Counter -ErrorAction SilentlyContinue).Counter
	$global:lines_act = (Get-Content $IISfile | Measure-Object -Line |Select-Object Lines).Lines
	$global:lines_delta = $lines_act - $lines_old
	Write-Host $lines_act "-" $lines_old "=" $lines_delta
	}
	
function Foutput {	
	Get-Content -Path $IISfile | select -First $lines_act | select -Last $lines_delta | Out-file $IISoutfile
	IF(!(Test-Path $reg_instancepath)) { New-Item -Path $reg_instancepath -Force | Out-Null }
    New-ItemProperty -Path $reg_instancepath -Name Counter -Value $lines_act -PropertyType STRING -Force | Out-Null
	
	#Write-Host $new_log_lines
   }
	
	fNewFile
	Counting

	if ($lines_delta -gt 0) {
		Foutput
		}
	elseif ($lines_delta -lt 0) {
		Write-Host "nesedí počty řádků, žádný výstup, resetuji počítadlo pro" $IIS_instance
		New-ItemProperty -Path $reg_instancepath -Name Counter -Value 0 -PropertyType STRING -Force | Out-Null
		}
	else {
		Write-Host "no new lines = no output file $IISoutfile"
		$no_lines = (Get-ItemProperty -Path $reg_basepath -Name NoLines -ErrorAction SilentlyContinue ).NoLines
		$no_lines ++
		IF(!(Test-Path $reg_basepath)) { New-Item -Path $reg_basepath -Force | Out-Null }
	    New-ItemProperty -Path $reg_basepath -Name NoLines -Value $no_lines -PropertyType DWORD -Force | Out-Null
		}
		
