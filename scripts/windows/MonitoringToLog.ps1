#
# Version 0.1
# Can use in NX-Log
$logFilePath = "D:\Logs\Monitoring\monitoring_status.json"
$shortMessage="Windos system monitoring values"
$fullMessage="Windos system monitoring values, cpu load in percent, disk usage and memory in GB"

$jsonString = '{ '

# OS informations
$osInfos = (Get-CimInstance Win32_OperatingSystem) | Select-Object Caption, Version
ForEach ($osInfo in $osInfos) {
	$jsonString = $jsonString + '"' + 'SysMonOSCaption' + '" : ' + '"' + $osInfo.Caption + '", ' + '"' + 'SysMonOSVersion' + '" : ' + '"' + $osInfo.Version + '", '	
	$loop = $loop + 1
}

# cpu load in percent
$cpuLoad =  Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select Average -ExpandProperty Average
$jsonString = $jsonString + '"' + 'SysMonCPULoad' + '" : ' + $cpuLoad + ', '

# memory values in GB
$totalMemory = Get-WmiObject Win32_OperatingSystem | Measure-Object -Property TotalVisibleMemorySize -Sum | % {[Math]::Round($_.sum/1024/1024)}
$jsonString = $jsonString + '"' + 'SysMonTotalMemory' + '" : ' + $totalMemory + ', '

$freeMemory = Get-WmiObject Win32_OperatingSystem | Measure-Object -Property FreePhysicalMemory -Sum | % {[Math]::Round($_.sum/1024/1024)}
$jsonString = $jsonString + '"' + 'SysMonFreeMemory' + '" : ' + $freeMemory + ', '

$swapUsed = Get-WmiObject Win32_PageFileUsage | % {[Math]::Round($_.sum/1024/1024)}
$jsonString = $jsonString + '"' + 'SysMonUsedSwap' + '" : ' + $swapUsed + ', '

# disk informations in kb
$loop = 0 
$diskInfos = Get-WMIObject Win32_LogicalDisk | Select Name, Size, FreeSpace
ForEach ($diskInfo in $diskInfos) {
	$count  = $count - 1
	$used =  [Math]::Round((($diskInfo.Size - $diskInfo.FreeSpace) * 100) / $diskInfo.Size, 2)
	$jsonString = $jsonString + '"' + 'SysMonPartition' + $loop + 'Name' + '" : ' + '"' + $diskInfo.Name + '", ' + '"' + 'SysMonPartition' + $loop + 'Used' + '" : ' + $used +', '	
	$loop = $loop + 1
}

# finalize the json string
$jsonString = $jsonString + '"' + 'short_message' + '" : ' + '"' + $shortMessage + '"' + ', '
$jsonString = $jsonString + '"' + 'full_message' + '" : ' + '"' + $fullMessage + '"'
$jsonString = $jsonString + ' }'

# create the json log file for NX-Log
Write-Output $jsonString | Out-File -Encoding utf8 -Append -FilePath $logFilePath