clear
$IIS_LogRotator_version = "1"

# is log for site of per server?
# netsh http flush logbuffer - vypsaní logů na disk
#$IIStoday = Get-Date -format "yyMMdd"  #https://technet.microsoft.com/en-us/library/ee692801.aspx

# config IIS file: C:\inetpub\history\CFGHISTORY_0000000020
#        <log centralLogFileMode="Site">
#            <centralBinaryLogFile enabled="true" directory="%SystemDrive%\inetpub\logs\LogFiles" />
#            <centralW3CLogFile enabled="true" directory="%SystemDrive%\inetpub\logs\LogFiles" logExtFileFlags="Date, Time, ClientIP, UserName, SiteName, ComputerName, ServerIP, Method, UriStem, UriQuery, HttpStatus, Win32Status, TimeTaken, ServerPort, UserAgent, Host, HttpSubStatus" />
#        </log>

$IIS_log_path = "C:\inetpub\logs\LogFiles\" #lomítko na konci NUTNÉ
$IIS_outdir = "M:\weby\Dropbox\old"
$reg_basepath = "HKLM:\Software\BSS\IIS_logrotator"


IF(!(Test-Path $reg_basepath)) { New-Item -Path $reg_basepath -Force | Out-Null }
New-ItemProperty -Path $reg_basepath -Name version -Value $IIS_LogRotator_version -PropertyType DWord -Force | Out-Null
$today = (Get-Date -format "yyMMdd")
$resetcounter = 0
$IIS_sites = Get-ChildItem -path $IIS_log_path


function Fmidnight
	{
	$global:reg_instancepath = $reg_basepath + "\" + $IIS_instance
	$today_old = (Get-ItemProperty -Path $reg_instancepath -Name LastDate -ErrorAction SilentlyContinue).LastDate
	#Write-Host $today " a " $today_old
	$day_delta = $today_old - $today
	
	IF($today_old - $today -eq -1) {
		Write-Host $day_delta "Byla půlnoc"
		IF(!(Test-Path $reg_instancepath)) { New-Item -Path $reg_instancepath -Force | Out-Null }
        New-ItemProperty -Path $reg_instancepath -Name LastDate -Value $today -PropertyType STRING -Force | Out-Null
	    $global:today = $today_old
		}
	ELSE {
		IF(!(Test-Path $reg_instancepath)) { New-Item -Path $reg_instancepath -Force | Out-Null }
        New-ItemProperty -Path $reg_instancepath -Name LastDate -Value $today -PropertyType STRING -Force | Out-Null
		}	
	}

function Counting
	{
	$global:IISfile = $IIS_log_path + $IIS_instance + "\u_ex" + $today + ".log"
	$global:IISoutfile = $IIS_outdir + "\IIS_" + $env:computername + "_" + $IIS_instance + "_" + $(Get-Date -format "yyMMdd-HHmmss") + ".log"
    Write-Host $IISfile
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

function FlushLogbuffer {
	$multi = ($IIS_sites).count * 10
	if ( $no_lines -gt $multi ) { 
		Invoke-Expression -Command "netsh http flush logbuffer" 
		New-ItemProperty -Path $reg_basepath -Name NoLines -Value 0 -PropertyType DWord -Force | Out-Null
		Write-Host "jede flash log buffer" $multi
		}
	}


foreach ($IIS_instance in $IIS_sites) {
# Write-Host $IISfile $IIS_instance
Fmidnight
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
	$no_lines = (Get-ItemProperty -Path $reg_basepath -Name NoLines).NoLines
	$no_lines ++
	IF(!(Test-Path $reg_basepath)) { New-Item -Path $reg_basepath -Force | Out-Null }
    New-ItemProperty -Path $reg_basepath -Name NoLines -Value $no_lines -PropertyType DWORD -Force | Out-Null
	}
	}
FlushLogbuffer
