# Script for determining selected monitoring parameters and integration into NX-Log and Graylog
# Tested on Microsoft Windows 2016, 2019 and 2022
# (C) Michael Schmidt
# Version 0.1 (01.12.2023)

$logFilePath = "C:\ProgramData\Monitoring\Logs\monitoring_status.json"
$shortMessage="Windos system monitoring values"
$fullMessage="Windos system monitoring values, cpu load and swap usage in percent, disk usage and memory in GB, failed (automatic started) services"

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

# swap usage in percent
$loop = 0
$allSwapUsed = 0
$swapInfos = Get-WmiObject Win32_PageFileUsage | where {$_.CurrentUsage}
ForEach ($swapInfo in $swapInfos) {
	if ($swapInfo.CurrentUsage -match "^\d+$") { 
		$swapUsed = [Math]::Round($swapInfo.CurrentUsage, 2)
		$name = $swapInfo.Name.substring(0,2)
		$jsonString = $jsonString + '"' + 'SysMonUsedSwap' + $loop + 'Name' + '" : ' + '"' + $name + '", ' + '"' + 'SysMonUsedSwap' + $loop + 'Used' + '" : ' + $swapUsed +', '	
		$loop = $loop + 1
		$allSwapUsed = $allSwapUsed + $swapUsed
	}
}
$jsonString = $jsonString + '"' + 'SysMonUsedSwap' + '" : ' + $allSwapUsed  +', '	

# disk informations in kb
$loop = 0 
$diskInfos = Get-WMIObject Win32_LogicalDisk | Select Name, Size, FreeSpace
ForEach ($diskInfo in $diskInfos) {
	if ($diskInfo.Size -match "^\d+$" -And $diskInfo.FreeSpace -match "^\d+$") { 
		$used =  [Math]::Round((($diskInfo.Size - $diskInfo.FreeSpace) * 100) / $diskInfo.Size, 2)
		$jsonString = $jsonString + '"' + 'SysMonPartition' + $loop + 'Name' + '" : ' + '"' + $diskInfo.Name + '", ' + '"' + 'SysMonPartition' + $loop + 'Used' + '" : ' + $used +', '	
		$loop = $loop + 1
	}
}

# failed services
# filter
$fiteredServices = 'edgeupdate', 'RemoteRegistry', 'sppsvc'
$failedServiceNames = @()
$stoppedServices = Get-Service | Where-Object {$_.Status -eq "Stopped"} | where Starttype -match Automatic
$failedServices = $stoppedServices.Count
ForEach ($stoppedService in $stoppedServices) {
	if ($fiteredServices -Contains $stoppedService.Name) {
		$failedServices = $failedServices -1
	} else {
		$failedServiceNames += $stoppedService.Name
	}
}

$jsonString = $jsonString + '"' + 'SysMonFailedServices' + '" : ' + $failedServices + ', ' + '"' + 'SysMonFailedServiceNames' + '" : ' + '"' + $failedServiceNames + '", '

# finalize the json string
$jsonString = $jsonString + '"' + 'short_message' + '" : ' + '"' + $shortMessage + '"' + ', '
$jsonString = $jsonString + '"' + 'full_message' + '" : ' + '"' + $fullMessage + '"'
$jsonString = $jsonString + ' }'

# create the json log file for NX-Log
Write-Output $jsonString | Out-File -Encoding utf8 -Append -FilePath $logFilePath